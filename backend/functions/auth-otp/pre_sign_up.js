'use strict';

/**
 * Cognito PreSignUp trigger: phone ownership is proven by the OTP at first sign-in,
 * so confirm the user and mark the phone as verified automatically.
 * Only Iraqi mobile numbers (+9647XXXXXXXXX) are accepted.
 */
const IRAQ_MOBILE = /^\+9647\d{9}$/;

exports.handler = async (event) => {
  const phone = event.request.userAttributes.phone_number || '';
  if (!IRAQ_MOBILE.test(phone)) {
    throw new Error('Invalid phone number');
  }
  event.response.autoConfirmUser = true;
  event.response.autoVerifyPhone = true;
  return event;
};
