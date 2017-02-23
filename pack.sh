#!/bin/bash
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

