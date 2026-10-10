'use strict';

const crypto = require('crypto');

/** Cognito VerifyAuthChallengeResponse trigger: constant-time compare of the entered code. */
exports.handler = async (event) => {
  const expected = String(event.request.privateChallengeParameters.code || '');
  const answer = String(event.request.challengeAnswer || '').trim();

  event.response.answerCorrect =
    expected.length === answer.length &&
    expected.length > 0 &&
    crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(answer));

  return event;
};
