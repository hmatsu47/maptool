const amplifyconfig = ''' {
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "maptool": {
                    "endpointType": "REST",
                    "endpoint": "https://[Endpoint].execute-api.ap-northeast-1.amazonaws.com/[Stage]",
                    "region": "ap-northeast-1",
                    "authorizationType": "API_KEY",
                    "apiKey": "[API Gateway Key]"
                }
            }
        }
    }
}''';
