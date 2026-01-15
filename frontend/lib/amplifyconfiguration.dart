const amplifyconfig = '''
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_PHPkG78b5",
            "AppClientId": "1tl9g7nk2k2chtj5fg960fgdth",
            "Region": "us-east-1"
          }
        }
      }
    }
  }
}
''';
