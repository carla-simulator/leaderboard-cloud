# Frontend

The last piece of the puzzle to finish the complete implementation of the Leaderboard infrastructure is the frontend, which in this case has been done at the EvalAI's platform, an open-source platform for easy evaluation of machine learning algorithms. Details about the frontend and how to set it up can be found in the [leaderboard-frontend](https://github.com/carla-simulator/leaderboard-frontend), but here is a general overview about it.

First of all, a user has to register to EvalAI, which will create a username for them. That user can then create participant and host teams. Host teams are used to set up a challenge, and each challenge is linked with a github repository. Participant teams can apply to any of the created challenges.

Once applied, users can do submissions which will be evaluated on EvalAI's backend, or the host's one, depending on how the challenge was set up. In the case of docker based submissions, the submissions have to be done using EvalAI's CLI commands. Each challenge is linked with an AWS SQS Queue and an AWS ECR, so that once a submission is created, its docker will be sent to ECR, and a message with its info onto the SQS Queue.

Instead of having one challenge per Leaderboard, it was decided to merge the two Leaderboards into a single challenge. This results in an easier, non-duplicated pipeline, while also removing the need for the users to have to participate in several challenges, avoiding confusions.