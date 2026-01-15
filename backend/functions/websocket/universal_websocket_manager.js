#!/usr/bin/env node

/**
 * Universal WebSocket Connection Manager
 * النظام الموحد لإدارة اتصالات WebSocket لجميع التطبيقات
 * 
 * Features:
 * 1. إنشاء سجل واحد بمعلومات كاملة عند الاتصال
 * 2. تحديث status (connect/disconnect) بدلاً من الحذف
 * 3. منع الاتصالات المتعددة للمستخدم الواحد
 * 4. تنظيف دوري للسجلات القديمة
 * 5. دعم جميع أنواع التطبيقات (driver, customer, business)
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, UpdateCommand, DeleteCommand, QueryCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

class UniversalWebSocketManager {
    constructor() {
        this.dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
        this.dynamoDB = DynamoDBDocumentClient.from(this.dynamoClient);
        this.connectionsTable = process.env.WEBSOCKET_CONNECTIONS_TABLE;
        if (!this.connectionsTable) {
            throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
        }
        
        // تكوين API Gateway WebSocket endpoint حسب التطبيق
        this.apiGatewayEndpoints = {
            driver: process.env.DRIVER_WEBSOCKET_ENDPOINT,
            customer: process.env.CUSTOMER_WEBSOCKET_ENDPOINT,
            business: process.env.BUSINESS_WEBSOCKET_ENDPOINT
        };
    }

    /**
     * إنشاء اتصال جديد مع معلومات كاملة
     * يدعم جميع أنواع التطبيقات
     */
    async handleConnect(connectionId, event) {
        try {
            const queryParams = event.queryStringParameters || {};
            const headers = event.headers || {};
            
            // استخراج المعلومات الأساسية
            const {
                token,
                userId,
                userType,
                entityType,
                businessId,
                driverId,
                deviceId,
                platform,
                appVersion
            } = queryParams;

            console.log(`🔌 اتصال جديد: ${connectionId}`, {
                userType, entityType, userId, businessId, driverId
            });

            // التحقق من الـ JWT والمستخدمين المسجلين والضيوف
            let verified = null;
            let finalUserId = null;
            let userCategory = 'guest'; // 'registered' أو 'guest'
            
            // أولاً: محاولة التحقق من JWT للمستخدمين المسجلين
            if (token) {
                try {
                    verified = await this.verifyJwt(token);
                    if (verified && (verified.sub || verified.email || verified.username)) {
                        finalUserId = verified.sub || verified.email || verified.username;
                        userCategory = 'registered';
                        console.log(`🔐 مستخدم مسجل: ${finalUserId}`);
                    }
                } catch (error) {
                    console.warn(`⚠️ فشل التحقق من JWT: ${error.message}`);
                }
            }
            
            // ثانياً: إذا لم يتم العثور على مستخدم مسجل، استخدم معرف الضيف
            if (!finalUserId && userId) {
                finalUserId = userId;
                userCategory = 'guest';
                console.log(`👤 مستخدم ضيف: ${finalUserId}`);
            }
            
            // ثالثاً: إذا لم يتم توفير أي معرف، إنشاء معرف ضيف عشوائي
            if (!finalUserId) {
                finalUserId = `guest-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                userCategory = 'guest';
                console.log(`👤 مستخدم ضيف جديد: ${finalUserId}`);
            }

            // تحديد نوع الكيان والمستخدم
            const finalEntityType = this.determineEntityType(userType, entityType, queryParams);
            
            // تحديد المستخدم حسب نوع الكيان
            if (!finalUserId) {
                if (finalEntityType === 'business' && queryParams.businessId) {
                    finalUserId = queryParams.businessId;
                    userCategory = 'business';
                    console.log(`🏪 اتصال متجر: ${finalUserId}`);
                } else if (finalEntityType === 'driver' && queryParams.driverId) {
                    finalUserId = queryParams.driverId;
                    userCategory = 'driver';
                    console.log(`🚗 اتصال سائق: ${finalUserId}`);
                } else {
                    finalUserId = `guest-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                    userCategory = 'guest';
                    console.log(`👤 مستخدم ضيف جديد: ${finalUserId}`);
                }
            }
            
            // البحث عن اتصالات موجودة لنفس المستخدم
            await this.disconnectExistingConnections(finalUserId, finalEntityType, connectionId);

            // إنشاء سجل الاتصال الجديد
            const connectionData = await this.createConnectionRecord(
                connectionId, 
                finalUserId, 
                finalEntityType, 
                queryParams, 
                verified
            );

            // حفظ الاتصال في قاعدة البيانات
            await this.dynamoDB.send(new PutCommand({
                TableName: this.connectionsTable,
                Item: connectionData
            }));

            console.log(`✅ تم حفظ الاتصال: ${connectionId} للمستخدم: ${finalUserId}`);
            
            return { statusCode: 200, body: 'Connected successfully' };

        } catch (error) {
            console.error('❌ خطأ في إنشاء الاتصال:', error);
            return { statusCode: 500, body: 'Connection failed' };
        }
    }

    /**
     * تحديث حالة الاتصال إلى منقطع بدلاً من الحذف
     */
    async handleDisconnect(connectionId) {
        try {
            console.log(`🔌 قطع الاتصال: ${connectionId}`);

            // تحديث حالة الاتصال
            await this.dynamoDB.send(new UpdateCommand({
                TableName: this.connectionsTable,
                Key: {
                    PK: `CONNECTION#${connectionId}`,
                    SK: `CONNECTION#${connectionId}`
                },
                UpdateExpression: 'SET #status = :status, #isActive = :isActive, #disconnectedAt = :disconnectedAt, #lastSeen = :lastSeen',
                ExpressionAttributeNames: {
                    '#status': 'status',
                    '#isActive': 'isActive',
                    '#disconnectedAt': 'disconnectedAt',
                    '#lastSeen': 'lastSeen'
                },
                ExpressionAttributeValues: {
                    ':status': 'disconnected',
                    ':isActive': false,
                    ':disconnectedAt': new Date().toISOString(),
                    ':lastSeen': new Date().toISOString()
                },
                ConditionExpression: 'attribute_exists(connectionId)'
            }));

            console.log(`✅ تم تحديث حالة الاتصال إلى منقطع: ${connectionId}`);
            return { statusCode: 200, body: 'Disconnected successfully' };

        } catch (error) {
            if (error.name === 'ConditionalCheckFailedException') {
                console.log(`ℹ️ الاتصال غير موجود: ${connectionId}`);
                return { statusCode: 200, body: 'Already disconnected' };
            }
            
            console.error('❌ خطأ في قطع الاتصال:', error);
            return { statusCode: 500, body: 'Disconnect failed' };
        }
    }

    /**
     * إنشاء سجل اتصال كامل المعلومات
     */
    async createConnectionRecord(connectionId, userId, entityType, queryParams, verified) {
        const now = new Date().toISOString();
        const ttl = Math.floor(Date.now() / 1000) + (24 * 60 * 60); // 24 ساعة

        // البيانات الأساسية
        const baseRecord = {
            PK: `CONNECTION#${connectionId}`,
            SK: `CONNECTION#${connectionId}`,
            connectionId,
            userId,
            entityType,
            connectionType: 'REAL',
            status: 'connected',
            isActive: true,
            connectedAt: now,
            lastSeen: now,
            lastActivity: now,
            lastHeartbeat: now,
            timestamp: now,
            ttl,
            authenticated: !!verified,
            source: this.determineSource(entityType, queryParams)
        };

        // إضافة البيانات الخاصة بكل نوع
        if (entityType === 'driver') {
            baseRecord.driverId = userId;
            baseRecord.userType = 'driver';
            baseRecord.GSI1PK = `DRIVER#${userId}`;
            baseRecord.GSI1SK = `CONNECTION#${connectionId}`;
        } else if (entityType === 'business' || entityType === 'merchant') {
            baseRecord.businessId = queryParams.businessId || userId;
            baseRecord.userType = 'business';
            baseRecord.GSI1PK = `BUSINESS#${baseRecord.businessId}`;
            baseRecord.GSI1SK = `CONNECTION#${connectionId}`;
        } else if (entityType === 'customer' || entityType === 'user') {
            baseRecord.userType = 'customer';
            baseRecord.GSI1PK = `USER#${userId}`;
            baseRecord.GSI1SK = `CONNECTION#${connectionId}`;
            
            // تحديد إذا كان المستخدم مسجل أم ضيف
            if (verified && verified.sub) {
                baseRecord.userCategory = 'registered';
                baseRecord.isRegistered = true;
            } else {
                baseRecord.userCategory = 'guest';
                baseRecord.isRegistered = false;
            }
        }

        // إضافة معلومات الجهاز والتطبيق
        if (queryParams.deviceId) baseRecord.deviceId = queryParams.deviceId;
        if (queryParams.platform) baseRecord.platform = queryParams.platform;
        if (queryParams.appVersion) baseRecord.appVersion = queryParams.appVersion;
        if (queryParams.businessId) baseRecord.businessId = queryParams.businessId;
        
        // إضافة معلومات إضافية خاصة بالمستخدمين
        if (queryParams.orderId) baseRecord.orderId = queryParams.orderId;
        if (queryParams.restaurantId) baseRecord.restaurantId = queryParams.restaurantId;
        if (queryParams.userType) baseRecord.userType = queryParams.userType;
        
        // معلومات الموقع إذا توفرت
        if (queryParams.latitude) baseRecord.latitude = queryParams.latitude;
        if (queryParams.longitude) baseRecord.longitude = queryParams.longitude;

        // معلومات المصادقة
        if (verified) {
            baseRecord.email = verified.email || null;
            baseRecord.groups = verified['cognito:groups'] || [];
        }

        return baseRecord;
    }

    /**
     * قطع الاتصالات الموجودة لنفس المستخدم
     */
    async disconnectExistingConnections(userId, entityType, currentConnectionId) {
        try {
            console.log(`🔍 البحث عن اتصالات موجودة للمستخدم: ${userId}`);

            // البحث باستخدام GSI
            const gsiKey = this.getGSIKey(entityType, userId);
            
            const existingConnections = await this.dynamoDB.send(new QueryCommand({
                TableName: this.connectionsTable,
                IndexName: 'GSI1',
                KeyConditionExpression: 'GSI1PK = :gsiPK',
                FilterExpression: '#status = :status AND #isActive = :isActive',
                ExpressionAttributeNames: {
                    '#status': 'status',
                    '#isActive': 'isActive'
                },
                ExpressionAttributeValues: {
                    ':gsiPK': gsiKey,
                    ':status': 'connected',
                    ':isActive': true
                }
            }));

            const connections = existingConnections.Items || [];
            console.log(`📊 وجدت ${connections.length} اتصالات نشطة للمستخدم: ${userId}`);

            // قطع الاتصالات القديمة
            for (const conn of connections) {
                if (conn.connectionId !== currentConnectionId) {
                    await this.dynamoDB.send(new UpdateCommand({
                        TableName: this.connectionsTable,
                        Key: {
                            PK: conn.PK,
                            SK: conn.SK
                        },
                        UpdateExpression: 'SET #status = :status, #isActive = :isActive, #disconnectedAt = :disconnectedAt',
                        ExpressionAttributeNames: {
                            '#status': 'status',
                            '#isActive': 'isActive',
                            '#disconnectedAt': 'disconnectedAt'
                        },
                        ExpressionAttributeValues: {
                            ':status': 'disconnected',
                            ':isActive': false,
                            ':disconnectedAt': new Date().toISOString()
                        }
                    }));
                    
                    console.log(`🔌 تم قطع الاتصال القديم: ${conn.connectionId}`);
                }
            }

        } catch (error) {
            console.error('❌ خطأ في قطع الاتصالات الموجودة:', error);
        }
    }

    /**
     * تنظيف السجلات القديمة
     */
    async cleanupOldRecords() {
        try {
            const cutoffTime = new Date(Date.now() - (48 * 60 * 60 * 1000)); // 48 ساعة
            const cutoffISO = cutoffTime.toISOString();

            console.log(`🧹 تنظيف السجلات المنقطعة الأقدم من: ${cutoffISO}`);

            // البحث عن السجلات القديمة
            const oldRecords = await this.dynamoDB.send(new ScanCommand({
                TableName: this.connectionsTable,
                FilterExpression: '#status = :status AND #disconnectedAt < :cutoff',
                ExpressionAttributeNames: {
                    '#status': 'status',
                    '#disconnectedAt': 'disconnectedAt'
                },
                ExpressionAttributeValues: {
                    ':status': 'disconnected',
                    ':cutoff': cutoffISO
                }
            }));

            const recordsToDelete = oldRecords.Items || [];
            console.log(`🗑️ وجدت ${recordsToDelete.length} سجل قديم للحذف`);

            // حذف السجلات القديمة
            for (const record of recordsToDelete) {
                await this.dynamoDB.send(new DeleteCommand({
                    TableName: this.connectionsTable,
                    Key: {
                        PK: record.PK,
                        SK: record.SK
                    }
                }));
                
                console.log(`🗑️ تم حذف السجل القديم: ${record.connectionId}`);
            }

            return { cleaned: recordsToDelete.length };

        } catch (error) {
            console.error('❌ خطأ في تنظيف السجلات القديمة:', error);
            return { error: error.message };
        }
    }

    // دوال مساعدة
    determineEntityType(userType, entityType, queryParams) {
        if (entityType) return entityType;
        if (userType === 'driver') return 'driver';
        if (userType === 'business' || userType === 'merchant') return 'business';
        if (userType === 'customer' || userType === 'user') return 'customer';
        if (queryParams.businessId) return 'business';
        if (queryParams.driverId) return 'driver';
        return 'customer'; // default
    }

    determineSource(entityType, queryParams) {
        const sourceMap = {
            driver: 'driver_app',
            business: 'business_app',
            merchant: 'business_app',
            customer: 'customer_app',
            user: 'customer_app'
        };
        return sourceMap[entityType] || 'unknown_app';
    }

    getGSIKey(entityType, userId) {
        const keyMap = {
            driver: `DRIVER#${userId}`,
            business: `BUSINESS#${userId}`,
            merchant: `BUSINESS#${userId}`,
            customer: `USER#${userId}`,
            user: `USER#${userId}`
        };
        return keyMap[entityType] || `USER#${userId}`;
    }

    async verifyJwt(token) {
        try {
            // للاختبار: استخراج البيانات من JWT بسيط
            if (token && token.startsWith('eyJ')) {
                const parts = token.split('.');
                if (parts.length >= 2) {
                    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
                    return payload;
                }
            }
            // في الإنتاج: استخدم AWS Cognito أو مكتبة JWT حقيقية
            return null;
        } catch (error) {
            console.warn('فشل في التحقق من JWT:', error.message);
            return null;
        }
    }

    /**
     * تحديث Heartbeat للاتصال
     */
    async updateHeartbeat(connectionId) {
        try {
            await this.dynamoDB.send(new UpdateCommand({
                TableName: this.connectionsTable,
                Key: {
                    PK: `CONNECTION#${connectionId}`,
                    SK: `CONNECTION#${connectionId}`
                },
                UpdateExpression: 'SET #lastHeartbeat = :now, #lastActivity = :now, #lastSeen = :now',
                ExpressionAttributeNames: {
                    '#lastHeartbeat': 'lastHeartbeat',
                    '#lastActivity': 'lastActivity',
                    '#lastSeen': 'lastSeen'
                },
                ExpressionAttributeValues: {
                    ':now': new Date().toISOString()
                },
                ConditionExpression: 'attribute_exists(connectionId)'
            }));

            return { statusCode: 200, body: 'Heartbeat updated' };
        } catch (error) {
            console.error('❌ خطأ في تحديث Heartbeat:', error);
            return { statusCode: 500, body: 'Heartbeat update failed' };
        }
    }

    /**
     * الحصول على إحصائيات الاتصالات
     */
    async getConnectionStats() {
        try {
            const result = await this.dynamoDB.send(new ScanCommand({
                TableName: this.connectionsTable,
                ProjectionExpression: '#status, entityType, connectedAt, disconnectedAt',
                ExpressionAttributeNames: {
                    '#status': 'status'
                }
            }));

            const connections = result.Items || [];
            const stats = {
                total: connections.length,
                connected: connections.filter(c => c.status === 'connected').length,
                disconnected: connections.filter(c => c.status === 'disconnected').length,
                byEntityType: {
                    driver: connections.filter(c => c.entityType === 'driver').length,
                    business: connections.filter(c => c.entityType === 'business').length,
                    customer: connections.filter(c => c.entityType === 'customer').length
                }
            };

            return stats;
        } catch (error) {
            console.error('❌ خطأ في جلب إحصائيات الاتصالات:', error);
            return null;
        }
    }
}

module.exports = { UniversalWebSocketManager };