'use strict';

/**
 * Cognito CreateAuthChallenge trigger.
 * Generates a 6-digit code, sends it via OTPIQ, and keeps it in privateChallengeParameters
 * (server-side only, never returned to the client).
 * The same code is reused for retries within one sign-in session to avoid extra SMS cost.
 */
const crypto = require('crypto');
const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

const ssm = new SSMClient({});
const OTPIQ_URL = 'https://api.otpiq.com/api/sms';
const PROVIDER = process.env.OTPIQ_PROVIDER || 'sms';
const SENDER_ID = process.env.OTPIQ_SENDER_ID || '';

let cachedKey;

async function getApiKey() {
  if (cachedKey) return cachedKey;
  const res = await ssm.send(new GetParameterCommand({
    Name: process.env.OTPIQ_KEY_PARAM,
    WithDecryption: true,
  }));
  cachedKey = res.Parameter.Value;
  return cachedKey;
}

async function sendOtp(phoneE164, code) {
  const body = {
    phoneNumber: phoneE164.replace(/^\+/, ''), // OTPIQ expects digits only, e.g. 9647XXXXXXXXX
    smsType: 'verification',
    verificationCode: code,
    provider: PROVIDER,
  };
  if (SENDER_ID) body.senderId = SENDER_ID;

  const res = await fetch(OTPIQ_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${await getApiKey()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error('OTPIQ send failed', res.status, text);
    throw new Error('Failed to send verification code');
  }
}

exports.handler = async (event) => {
  const session = event.request.session || [];
  const phone = event.request.userAttributes.phone_number;

  let code;
  const previous = [...session].reverse().find((s) => s.challengeMetadata && s.challengeMetadata.startsWith('CODE-'));

  const reviewPhone = process.env.REVIEW_TEST_PHONE || '';
  if (reviewPhone && phone === reviewPhone) {
    // App Store review account: fixed code, no SMS.
    code = process.env.REVIEW_TEST_CODE || '123456';
  } else if (previous) {
    // Retry inside the same session: reuse the code, do not send another SMS.
    code = previous.challengeMetadata.slice(5);
  } else {
    code = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
    await sendOtp(phone, code);
  }

  event.response.publicChallengeParameters = { phone: phone.replace(/\d(?=\d{4})/g, '*') };
  event.response.privateChallengeParameters = { code };
  event.response.challengeMetadata = `CODE-${code}`;
  return event;
};
