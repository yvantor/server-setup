# Server Setup
A collection of scripts to quickly setup a small server environment with multiple users.
At the moment, the project contains:
* CreateUser.sh -> the executable script used for creating a new user or deleting an existing one.

## Instructions
The `CreateUser.sh` script should be executed as a server admin with sudo rights. In order to create a new user called
`user1` just run:
```
sudo ./path-to-your/CreateUser.sh create user1
``` 
The script will generate a `/home/admin/users/user1/user1.txt` file containing the Username and a random Password for
the created user, and a `/home/user1/` directory with a `.bashrc` and a `.bash_profile` identical to those in the
`/home/admin`.

To delete an existing user, just run:
```
sudo ./path-to-your/CreateUser.sh delete user1
```
This will delete the `/home/user1` and `/home/admin/users/user1` directories.
