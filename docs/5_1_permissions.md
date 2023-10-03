# AWS permissions

The first step in setting up the AWS components is, as one can imagine, to have an account. To do so, feel free to follow the official docs available [here](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html).

Once the account is ready, a user will be needed with the necessary permissions to manipulate the different AWS services. By default, new users have no permissions whatsoever (except for the initial one which has admin privileges), and all the required ones have to be specified. This is done using the IAM service, which links a speficic *Action* with a *Resource*. For example the following code, allows a user to update an item inside the *Deliveries* DynamoDB table.

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"dynamodb:UpdateItem"
			],
			"Resource": "arn:aws:dynamodb:*:*:table/Deliveries*"
		},
	]
}
```

To deploy the Leaderboard's cloud infraestructure, it is recommended to have either *admin* privileges, or make use of the permissions listed in [this file](/aws/policies/permissions/admin.json), which provides near full access to all the AWS services used, along with the [eksctl_minimum policies](/aws/policies/permissions/eksctl_minimum.json). For an even more robust permission scheme, users can make user of [this permissions](/aws/policies/permissions/user.json), which only provides access to the elements part of the Leaderboard infraestructure. These last permissions have the main setback of needing another user to create the elements that will be used by the cloud infraestructure, which names will have to be substituted in the previous linked document. The EKSctl minimum permissions files will also still be needed.