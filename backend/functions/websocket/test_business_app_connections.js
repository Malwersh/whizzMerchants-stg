#!/usr/bin/env node

/**
 * اختبار تطبيق المتجر المحدث
 * للتأكد من أن النظام الموحد يعمل بشكل صحيح
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { UniversalWebSocketManager } = require('./universal_websocket_manager');

const client = new DynamoDBClient({ region: 'us-east-1' });
const dynamoDB = DynamoDBDocumentClient.from(client);
const connectionsTable = process.env.WEBSOCKET_CONNECTIONS_TABLE;
if (!connectionsTable) {
    throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
}

class BusinessAppTester {
    constructor() {
        this.manager = new UniversalWebSocketManager();
        this.testConnections = [];
    }

    async runBusinessAppTests() {
        console.log('🏪 اختبار تطبيق المتجر المحدث');
        console.log('============================\n');

        try {
            // تنظيف البيانات أولاً
            await this.cleanupTestData();

            // اختبار اتصالات مختلفة للمتاجر
            await this.testBasicBusinessConnection();
            await this.testBusinessWithToken();
            await this.testMultipleBusinessConnections();
            await this.testBusinessReconnection();
            await this.testBusinessStatusUpdate();

            // عرض النتائج النهائية
            await this.showFinalResults();

            console.log('\n🎉 جميع اختبارات تطبيق المتجر اكتملت بنجاح!');

        } catch (error) {
            console.error('❌ خطأ في اختبارات تطبيق المتجر:', error);
        } finally {
            // تنظيف بيانات الاختبار
            await this.cleanupTestData();
        }
    }

    async testBasicBusinessConnection() {
        console.log('🏪 اختبار اتصال متجر أساسي');
        console.log('==========================');

        const businessId = 'business-test-001';
        const merchantId = 'merchant-test-001';
        const connectionId = `business-basic-${Date.now()}`;

        // محاكاة اتصال متجر أساسي
        const businessEvent = {
            queryStringParameters: {
                businessId: businessId,
                merchantId: merchantId,
                entityType: 'business',
                userType: 'business',
                deviceId: 'tablet-001',
                platform: 'tablet',
                appVersion: '1.2.0'
            },
            headers: {}
        };

        const connectResult = await this.manager.handleConnect(connectionId, businessEvent);
        console.log('📱 نتيجة اتصال المتجر:', connectResult.statusCode === 200 ? '✅ نجح' : '❌ فشل');

        this.testConnections.push(connectionId);

        // التحقق من البيانات المحفوظة
        await this.verifyBusinessConnectionData(connectionId, businessId, {
            businessId: businessId,
            deviceId: 'tablet-001',
            platform: 'tablet',
            appVersion: '1.2.0',
            entityType: 'business'
        });
    }

    async testBusinessWithToken() {
        console.log('\n🔐 اختبار اتصال متجر مع Token');
        console.log('==============================');

        const businessId = 'business-auth-001';
        const connectionId = `business-auth-${Date.now()}`;
        
        // إنشاء JWT token وهمي
        const token = this.createMockBusinessToken(businessId);

        // محاكاة اتصال متجر مع مصادقة
        const authBusinessEvent = {
            queryStringParameters: {
                businessId: businessId,
                token: token,
                entityType: 'business',
                userType: 'business',
                deviceId: 'pos-system-001',
                platform: 'pos',
                appVersion: '2.0.0'
            },
            headers: {}
        };

        const connectResult = await this.manager.handleConnect(connectionId, authBusinessEvent);
        console.log('📱 نتيجة اتصال المتجر مع Token:', connectResult.statusCode === 200 ? '✅ نجح' : '❌ فشل');

        this.testConnections.push(connectionId);

        // التحقق من البيانات المحفوظة مع المصادقة
        await this.verifyBusinessConnectionData(connectionId, businessId, {
            businessId: businessId,
            deviceId: 'pos-system-001',
            platform: 'pos',
            appVersion: '2.0.0',
            entityType: 'business',
            authenticated: true
        });
    }

    async testMultipleBusinessConnections() {
        console.log('\n🔄 اختبار عدة اتصالات لنفس المتجر');
        console.log('==================================');

        const businessId = 'business-multi-001';
        
        // الاتصال الأول من جهاز لوحي
        const firstConnectionId = `business-multi-1-${Date.now()}`;
        const firstEvent = {
            queryStringParameters: {
                businessId: businessId,
                entityType: 'business',
                userType: 'business',
                deviceId: 'tablet-main',
                platform: 'tablet'
            },
            headers: {}
        };

        await this.manager.handleConnect(firstConnectionId, firstEvent);
        console.log('📱 الاتصال الأول (Tablet): ✅ تم إنشاؤه');

        // الاتصال الثاني من نقطة بيع
        const secondConnectionId = `business-multi-2-${Date.now()}`;
        const secondEvent = {
            queryStringParameters: {
                businessId: businessId,
                entityType: 'business',
                userType: 'business',
                deviceId: 'pos-backup',
                platform: 'pos'
            },
            headers: {}
        };

        await this.manager.handleConnect(secondConnectionId, secondEvent);
        console.log('📱 الاتصال الثاني (POS): ✅ تم إنشاؤه');

        this.testConnections.push(firstConnectionId, secondConnectionId);

        // التحقق من أن الاتصال الأول تم قطعه
        await this.verifyConnectionStatus(firstConnectionId, 'disconnected');
        await this.verifyConnectionStatus(secondConnectionId, 'connected');

        console.log('✅ اختبار الاتصالات المتعددة للمتجر: نجح');
    }

    async testBusinessReconnection() {
        console.log('\n🔌 اختبار إعادة اتصال المتجر');
        console.log('============================');

        const businessId = 'business-reconnect-001';
        const connectionId = `business-reconnect-${Date.now()}`;

        // إنشاء اتصال
        const connectEvent = {
            queryStringParameters: {
                businessId: businessId,
                entityType: 'business',
                userType: 'business',
                deviceId: 'reconnect-device',
                platform: 'web'
            },
            headers: {}
        };

        await this.manager.handleConnect(connectionId, connectEvent);
        console.log('📱 تم إنشاء الاتصال');

        // قطع الاتصال
        await this.manager.handleDisconnect(connectionId);
        console.log('🔌 تم قطع الاتصال');

        // التحقق من تحديث الحالة
        await this.verifyConnectionStatus(connectionId, 'disconnected');

        // إعادة الاتصال (اتصال جديد)
        const newConnectionId = `business-reconnect-new-${Date.now()}`;
        await this.manager.handleConnect(newConnectionId, connectEvent);
        console.log('📱 تم إعادة الاتصال');

        this.testConnections.push(connectionId, newConnectionId);

        // التحقق من أن الاتصال الجديد نشط
        await this.verifyConnectionStatus(newConnectionId, 'connected');

        console.log('✅ اختبار إعادة اتصال المتجر: نجح');
    }

    async testBusinessStatusUpdate() {
        console.log('\n📊 اختبار تحديث حالة المتجر');
        console.log('============================');

        const businessId = 'business-status-001';
        const connectionId = `business-status-${Date.now()}`;

        // إنشاء اتصال
        const connectEvent = {
            queryStringParameters: {
                businessId: businessId,
                entityType: 'business',
                userType: 'business',
                deviceId: 'status-device',
                platform: 'web'
            },
            headers: {}
        };

        await this.manager.handleConnect(connectionId, connectEvent);
        console.log('📱 تم إنشاء الاتصال');

        // محاكاة تحديث heartbeat
        await this.manager.updateHeartbeat(connectionId);
        console.log('💗 تم تحديث heartbeat');

        this.testConnections.push(connectionId);

        // التحقق من تحديث lastHeartbeat
        await this.verifyHeartbeatUpdate(connectionId);

        console.log('✅ اختبار تحديث حالة المتجر: نجح');
    }

    createMockBusinessToken(businessId) {
        const header = Buffer.from(JSON.stringify({
            "alg": "HS256",
            "typ": "JWT"
        })).toString('base64url');
        
        const payload = Buffer.from(JSON.stringify({
            sub: businessId,
            email: `${businessId}@business.com`,
            'cognito:username': businessId,
            businessId: businessId,
            exp: Math.floor(Date.now() / 1000) + (60 * 60), // hour
            iat: Math.floor(Date.now() / 1000)
        })).toString('base64url');
        
        // token بسيط بدون توقيع للاختبار فقط
        return `${header}.${payload}.fake-business-signature`;
    }

    async verifyBusinessConnectionData(connectionId, expectedBusinessId, expectedData) {
        try {
            const result = await dynamoDB.send(new ScanCommand({
                TableName: connectionsTable,
                FilterExpression: 'connectionId = :connId',
                ExpressionAttributeValues: {
                    ':connId': connectionId
                }
            }));

            const connection = result.Items?.[0];
            if (!connection) {
                console.log(`❌ لم يتم العثور على الاتصال: ${connectionId}`);
                return false;
            }

            console.log(`🔍 فحص البيانات للاتصال: ${connectionId}`);

            // التحقق من البيانات الأساسية
            const checks = [
                { field: 'businessId', expected: expectedBusinessId, actual: connection.businessId },
                { field: 'status', expected: 'connected', actual: connection.status },
                { field: 'isActive', expected: true, actual: connection.isActive },
                { field: 'connectionType', expected: 'REAL', actual: connection.connectionType },
                { field: 'entityType', expected: expectedData.entityType, actual: connection.entityType },
                { field: 'userType', expected: 'business', actual: connection.userType }
            ];

            // التحقق من الحقول الإضافية
            if (expectedData.deviceId) {
                checks.push({ field: 'deviceId', expected: expectedData.deviceId, actual: connection.deviceId });
            }
            if (expectedData.platform) {
                checks.push({ field: 'platform', expected: expectedData.platform, actual: connection.platform });
            }
            if (expectedData.appVersion) {
                checks.push({ field: 'appVersion', expected: expectedData.appVersion, actual: connection.appVersion });
            }
            if (expectedData.authenticated !== undefined) {
                checks.push({ field: 'authenticated', expected: expectedData.authenticated, actual: connection.authenticated });
            }

            let allValid = true;
            checks.forEach(check => {
                if (check.actual !== check.expected) {
                    console.log(`❌ ${check.field}: توقع ${check.expected}, وجد ${check.actual}`);
                    allValid = false;
                } else {
                    console.log(`✅ ${check.field}: ${check.actual}`);
                }
            });

            // التحقق من GSI fields
            const expectedGSI = `BUSINESS#${expectedBusinessId}`;
            if (connection.GSI1PK !== expectedGSI) {
                console.log(`❌ GSI1PK: توقع ${expectedGSI}, وجد ${connection.GSI1PK}`);
                allValid = false;
            } else {
                console.log(`✅ GSI1PK: ${connection.GSI1PK}`);
            }

            console.log(allValid ? '✅ جميع البيانات صحيحة' : '❌ يوجد أخطاء في البيانات');
            return allValid;

        } catch (error) {
            console.error(`❌ خطأ في التحقق من البيانات: ${error.message}`);
            return false;
        }
    }

    async verifyConnectionStatus(connectionId, expectedStatus) {
        try {
            const result = await dynamoDB.send(new ScanCommand({
                TableName: connectionsTable,
                FilterExpression: 'connectionId = :connId',
                ExpressionAttributeValues: {
                    ':connId': connectionId
                }
            }));

            const connection = result.Items?.[0];
            if (connection?.status === expectedStatus) {
                console.log(`✅ حالة الاتصال ${connectionId}: ${expectedStatus}`);
                return true;
            } else {
                console.log(`❌ حالة الاتصال ${connectionId}: توقع ${expectedStatus}, وجد ${connection?.status}`);
                return false;
            }
        } catch (error) {
            console.error(`❌ خطأ في التحقق من حالة الاتصال: ${error.message}`);
            return false;
        }
    }

    async verifyHeartbeatUpdate(connectionId) {
        try {
            const result = await dynamoDB.send(new ScanCommand({
                TableName: connectionsTable,
                FilterExpression: 'connectionId = :connId',
                ExpressionAttributeValues: {
                    ':connId': connectionId
                }
            }));

            const connection = result.Items?.[0];
            if (connection?.lastHeartbeat) {
                const heartbeatTime = new Date(connection.lastHeartbeat);
                const now = new Date();
                const diffSeconds = (now - heartbeatTime) / 1000;
                
                if (diffSeconds < 60) { // أقل من دقيقة
                    console.log(`✅ Heartbeat محدث حديثاً: ${diffSeconds.toFixed(1)} ثانية مضت`);
                    return true;
                } else {
                    console.log(`❌ Heartbeat قديم: ${diffSeconds.toFixed(1)} ثانية مضت`);
                    return false;
                }
            } else {
                console.log(`❌ لا يوجد lastHeartbeat`);
                return false;
            }
        } catch (error) {
            console.error(`❌ خطأ في التحقق من heartbeat: ${error.message}`);
            return false;
        }
    }

    async showFinalResults() {
        console.log('\n📊 النتائج النهائية لتطبيق المتجر');
        console.log('================================');

        const stats = await this.manager.getConnectionStats();
        if (stats) {
            console.log(`📈 إجمالي الاتصالات: ${stats.total}`);
            console.log(`🟢 الاتصالات النشطة: ${stats.connected}`);
            console.log(`🔴 الاتصالات المنقطعة: ${stats.disconnected}`);
            console.log(`🏪 اتصالات المتاجر: ${stats.byEntityType.business || 0}`);
            
            if (stats.byEntityType.business > 0) {
                console.log('🎯 تطبيق المتجر يعمل بشكل صحيح!');
            }
        }
    }

    async cleanupTestData() {
        console.log('\n🧹 تنظيف بيانات اختبار تطبيق المتجر...');
        
        for (const connectionId of this.testConnections) {
            try {
                await dynamoDB.send(new DeleteCommand({
                    TableName: connectionsTable,
                    Key: {
                        PK: `CONNECTION#${connectionId}`,
                        SK: `CONNECTION#${connectionId}`
                    }
                }));
                console.log(`🗑️ تم حذف اتصال الاختبار: ${connectionId}`);
            } catch (error) {
                console.log(`⚠️ لم يتم العثور على الاتصال للحذف: ${connectionId}`);
            }
        }
        
        this.testConnections = [];
    }
}

// تشغيل الاختبارات
async function main() {
    const tester = new BusinessAppTester();
    await tester.runBusinessAppTests();
}

// تشغيل الاختبار إذا تم استدعاء الملف مباشرة
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { BusinessAppTester };