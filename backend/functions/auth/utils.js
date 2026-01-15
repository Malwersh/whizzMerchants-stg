'use strict';
const { jwtDecode } = require('jwt-decode');

function getBusinessIdFromToken(authHeader) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }

    try {
        const token = authHeader.replace('Bearer ', '');
        const decoded = jwtDecode(token);
        return decoded.businessId || null;
    } catch (error) {
        console.error('Error decoding token:', error);
        return null;
    }
}

function createResponse(statusCode, body) {
    return {
        statusCode: statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}

module.exports = { createResponse, getBusinessIdFromToken };
