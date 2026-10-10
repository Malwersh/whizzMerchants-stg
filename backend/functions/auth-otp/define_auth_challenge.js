'use strict';

/**
 * Cognito DefineAuthChallenge trigger (phone OTP, passwordless).
 * Flow: CUSTOM_CHALLENGE (OTP via OTPIQ) -> tokens. Max 3 wrong attempts per session.
 */
const MAX_ATTEMPTS = 3;

exports.handler = async (event) => {
  const session = event.request.session || [];

  if (event.request.userNotFound) {
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
    return event;
  }

  const last = session[session.length - 1];

  if (last && last.challengeName === 'CUSTOM_CHALLENGE' && last.challengeResult === true) {
    event.response.issueTokens = true;
    event.response.failAuthentication = false;
  } else if (session.length >= MAX_ATTEMPTS) {
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
  } else {
    event.response.issueTokens = false;
    event.response.failAuthentication = false;
    event.response.challengeName = 'CUSTOM_CHALLENGE';
  }

  return event;
};
