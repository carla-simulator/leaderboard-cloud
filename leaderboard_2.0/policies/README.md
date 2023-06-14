```sh

PIPE_ROLE_NAME="LeaderboardPipeRole"
LAMBDA_ROLE_NAME="LeaderboardLambdaRole"
SF_ROLE_NAME="LeaderboardStepFunctionRole"

PIPE_POLICY_NAME="LeaderboardPipePolicy"
LAMBDA_POLICY_NAME="LeaderboardLambdaPolicy"
SF_POLICY_NAME="LeaderboardStepFunctionPolicy"

aws iam create-role --role-name=$PIPE_ROLE_NAME --assume-role-policy-document "file://trust_relationships/pipe.json"
aws iam put-role-policy --role-name $PIPE_ROLE_NAME --policy-name $PIPE_POLICY_NAME --policy-document "file://permissions/pipe.json"

aws iam create-role --role-name=$LAMBDA_ROLE_NAME --assume-role-policy-document "file://trust_relationships/lambda.json"
aws iam put-role-policy --role-name $LAMBDA_ROLE_NAME --policy-name $LAMBDA_POLICY_NAME --policy-document "file://permissions/lambda.json"

aws iam create-role --role-name=$SF_ROLE_NAME --assume-role-policy-document "file://trust_relationships/stepfunction.json"
aws iam put-role-policy --role-name $SF_ROLE_NAME --policy-name $SF_POLICY_NAME --policy-document "file://permissions/stepfunction.json"

```
