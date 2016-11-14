#!/bin/bash
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
