command="$1"
if [ "$command" = "up" ]
then
    ruby logic.rb prep &&
    source scripts/prepare-docker.sh &&
    ruby logic.rb start &&
    source scripts/add-aliases.sh
fi

if [ "$command" = "halt" ]
then
    source scripts/prepare-docker.sh &&
    ruby logic.rb stop &&
    source scripts/add-aliases.sh &&
    source scripts/remove-aliases.sh
fi

if [ "$command" = "reload" ]
then
    source scripts/prepare-docker.sh &&
    ruby logic.rb stop &&

    ruby logic.rb prep &&
    source scripts/prepare-docker.sh &&
    ruby logic.rb start &&
    source scripts/add-aliases.sh
fi

if [ "$command" = "destroy" ]
then
    source scripts/prepare-docker.sh &&
    ruby logic.rb reset &&
    export COMPOSE_FILE= &&
    export COMPOSE_PROJECT_NAME= &&
    source scripts/add-aliases.sh &&
    source scripts/remove-aliases.sh
fi

if [ "$command" = "repair" ]
then
    source scripts/prepare-docker.sh &&
    source scripts/add-aliases.sh
fi
