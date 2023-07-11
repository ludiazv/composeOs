# composeOS stacks folder

In this folder, the templates ```docker-compose.yml``` files should be placed to described the software stacks required in ```composeos.yml``` configuration file.
Check the examples provided in this folder to define your own stacks in standard _docker-compose_ notation.


Please read carefully the sections below to customize or create your own templates.


## Image names

**composeOS** resolve name in multiple registers for the image names that could create ambiguty. It is recommended to define full name of the image. For example for the cotainer ```portainer-ce``` it's recommended to set the image to ```docker.io/portainer/portainer-ce``` instead of ```portainer/portainer-ce```.


## Environment variables & special syntax

compose files follows the usal notation but composeOS include some special syntax to manage enviroment variables to make more general compose templates. Env variables are useful 
to parametrize the container/stack behaviour, for example, to change the exposed port a variable can be used. Check out the following snippet:


```yaml
# Default parameters
##PORT=1234
---
...
services:
  my_service:
    image: reg/usr/myimage:${TAG}
    ...
    ports:
      - ${PORT}:8080

...

```

In this example, _PORT_  and _TAG_ are parameteres in the compose file. Now is possible to change the image tag and exposed service port with parameters so there is no need to change the compose file to change any of these features.

Note the syntax in the top section with a double comment marker ```##``` that define the default parameter vaule in case is not defined. Another marker ```#!``` can be used to override values within the compose file.


Environment varariables precedence (from less to higher precedence):

1. Default values defined with the marker ```##```
2. System builtin variables: ```COS_UID, COS_GID,TAG,....```
3. Global variables defined in composeos.yml ```compose.env``` that are common to all stacks.
4. Values defined with the marker ```#!```.
5. Values defined with the directive in composeos.yml ```compose.run.<stack_name>.env```.

By defalt the following variables are defined:

```

COS_USER="composeos"
COS_GROUP="composeos"
COS_UID=1000
COS_GID=1000
COS_MAINSTORAGE=<full path of mainstorage>
TZ=<configured timezone name>
TAG=latest
STACK_NAME=<name of the stack name>
STACK_FOLDER=<full path of folder for the directory created for deploying the stack>

```


