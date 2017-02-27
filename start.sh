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

CDH_EXECUTABLE_DIR_POSTFIX=".cloudera.YARN"
FOR_SCANNING=${HADOOP_CONF_DIR%/}${CDH_EXECUTABLE_DIR_POSTFIX}
if [ -e ${FOR_SCANNING} ]
then
	for file in $( ls ${FOR_SCANNING} ); do
		if [ -f ${FOR_SCANNING}/${file} ]
		then
			chmod 0755 ${FOR_SCANNING}/${file}
		fi
	done
fi	
exec "$@"
