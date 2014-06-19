#!/bin/sh

set -e

PROJECT_PATH=$(mktemp -d)
DJANGO_TEMPLATE=http://liip.to/django-template

OPTIND=1
while getopts 'p:d:h' flag; do
  case "${flag}" in
    p)  rmdir $PROJECT_PATH;
        PROJECT_PATH="${OPTARG}"
        if [ ! -d $PROJECT_PATH ]; then
            mkdir -p $PROJECT_PATH
        fi ;;
    d) DJANGO_TEMPLATE="${OPTARG}" ;;
    h|?) echo "Usage: $0 [-p project/path/] [-d django-template-url-or-dir] project_name" 1>&2;
       return 1;;
  esac
done
shift $((OPTIND - 1))

PROJECT_NAME=${1:-dummy-project-name}

if ! python -c 'import sys; print sys.real_prefix' >/dev/null 2>&1 ; then
    echo "Not running from within a virtualenv, will break your system; aborting;" 1>&2
    return 2
fi

if ! python -c 'import django' >/dev/null 2>&1 ; then
    pip install django
fi

django_admin=`which django-admin.py`

echo "* Create project $PROJECT_NAME in $PROJECT_PATH from $DJANGO_TEMPLATE"
$django_admin startproject --template=$DJANGO_TEMPLATE $PROJECT_NAME $PROJECT_PATH

cd $PROJECT_PATH
echo "* Make manage.py executable"
chmod +x manage.py

echo "* Remove this very script"
rm $(basename $0) || :

echo "* Initialize git project in $PROJECT_PATH"
git init
git add -A .
git commit -m "Project '$PROJECT_NAME' initialized in $PROJECT_PATH"

echo "* Setup virtualenv for the development environment"
pip install -r ./requirements/dev.txt

echo "* Prepare for a local SQLite database"
sqlite_dbname=./${PROJECT_NAME}.sqlite
echo "sqlite://$sqlite_dbname" > ./envdir/local/DATABASE_URL
echo "$sqlite_dbname" >> .gitignore
git add .gitignore
git commit -m "Ignore local SQLite DB"

echo "* Initialize DB, be prepared to create your first local user"
./manage.py syncdb

echo " * Run the initial DB migration "
./manage.py migrate

echo " === PROJECT CREATED in ${PROJECT_PATH} === "
echo ""
