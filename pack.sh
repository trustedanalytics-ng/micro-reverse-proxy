#!/bin/bash
if [ ! -e $PWD/target ]
then
	mkdir $PWD/target
fi 

if [ ! $? -eq 0 ]
then 
	echo "Can't prepare env for build!" 
	exit 1
fi

docker build -t mrp_build -f build/Dockerfile . 

if [ ! $? -eq 0 ]
then 
	echo "Can't build image for compilation!" 
	exit 1
fi

docker run --rm --volume="$PWD/target:/opt" --volume="$PWD/target:/target" -t mrp_build

if [ ! $? -eq 0 ]
then 
	echo "Can't build micro-reverse-proxy image!" 
	exit 1
fi

