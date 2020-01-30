# Fast-er-italy-backend
A Ruby-on-Rails back-end for the android application [Fast ER Italy](https://github.com/bersa125/fast-er-italy-app).
The package has been created using Rails and manages the connections between the app and the saved user's cloud-data. 
It synchronizes the information on a local database and duplicates them on a configured Firebase Real-time Database.
## Needed software dependencies
The back-end needs Postgresql and Ruby 2.6.0 installed and running on the machine.
## Commands needed to run the back-end locally
In a terminal running in the project's directory:
```bash
#First define the correct variables used by the application
export PATH=$PATH:~/ruby/2.6.0/bin
export FIREBASE_PROJECT_ID=''
export FIREBASE_PROJECT_DATABASE_URI=''
export FIREBASE_SDK_SECRET=''
export MAX_ALLOWED_DAILY_SUBMISSIONS=3
export MAX_ALLOWED_DAILY_MODIFICATIONS=5
export MAX_ALLOWED_ADDRESSES=10
#Launch it with Rails
rails db:drop
rails db:create
rails db:migrate
rails server
```
