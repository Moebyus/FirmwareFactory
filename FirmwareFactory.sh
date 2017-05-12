#	Moebyus Firmware Generator
#
#
#
#

#!/bin/bash


#Variables
ARDUINO_PATH="/home/moebyusdev/arduino-1.8.2"
FIRMWARE_URL="https://github.com/moebyus/Marlin"
FIRMWARE_FILE="Marlin.hex"

#Paths
BASE_PATH=$PWD
TMP_PATH=$BASE_PATH"/tmp"
BUILD_PATH=$TMP_PATH"/build"
SOURCES_PATH=$BUILD_PATH"/sources"
EXPORT_PATH=$BASE_PATH"/Firmwares"
MARLIN_TEMPLATE_PATH=$TMP_PATH"/MarlinTemplate"

#Funciones

shit_happened_count=0

createDirs()
{
	echo "BasePath:" $BASE_PATH
	mkdir -p "$BUILD_PATH"
	mkdir -p "$TMP_PATH"
}


cleanBuild()
{
	if [ -d "$BUILD_PATH" ] ; then
		echo "Limpiando" $BUILD_PATH
		cd $BUILD_PATH
		rm -rf *
	fi

	if [ -d "$EXPORT_PATH" ] ; then
		echo "Limpiando" $EXPORT_PATH
		cd $EXPORT_PATH
		rm -rf *
	fi
	
}

cleanAll()
{
	if [ -d "$TMP_PATH" ] ; then
	echo "Limpiando" $TMP_PATH
		cd $TMP_PATH
		rm -rf *
	fi
	cleanBuild
}

getFirmwareTemplate()
{
	echo "Comprobando plantilla del fimware..." "$MARLIN_TEMPLATE_PATH"
	if [ -d "$MARLIN_TEMPLATE_PATH" ];then
		echo "Ya la tengo."
	else
		echo "Clonando..."
		git clone $FIRMWARE_URL "$MARLIN_TEMPLATE_PATH"
		if [ "$?" -ne 0 ];then echo "Algo ha ido mal." ; return 1; fi
	fi
}

buildMarlinPath()
{
	echo "----------" | figlet
	MARLIN_PATH=$1
	DESTINATION=$2
		
	if [ -d "$MARLIN_PATH" ];then
		echo "Firmware : "$MARLIN_PATH
	else
		echo "No encuentro:"$MARLIN_PATH
		return 1
	fi
	
	JOB_NAME=`basename $MARLIN_PATH`
	CMAKE_FILE=$MARLIN_PATH/buildroot/share/cmake/CMakeLists.txt
	JOB_PATH=$BUILD_PATH/$JOB_NAME
	LOGFILE=$JOB_PATH/log.txt

	if [ -d "$2" ];then
		DESTINATION=$2
	else
		DESTINATION=$JOB_PATH
	fi

	FINAL_FILE=$DESTINATION"/"$JOB_NAME".hex"
	echo $JOB_NAME | figlet
	echo "Compilando en" $JOB_PATH
	mkdir -p $JOB_PATH
    touch $LOGFILE
	cd $JOB_PATH
	cmake $CMAKE_FILE -DARDUINO_SDK_PATH=$ARDUINO_PATH -B$JOB_PATH &>> $LOGFILE
	make &>> $LOGFILE
	RESULT_FILE=$JOB_PATH/$FIRMWARE_FILE
	if [ -f "$RESULT_FILE" ];then
		cp $RESULT_FILE $FINAL_FILE
		echo "Generado:" $FINAL_FILE		
		echo "ok" | figlet
		return 0
	else
		echo "fail" | figlet
		return 1
	fi
}


prepareFirmwares()
{
	echo "Preparando firmwares"
    cd $BASE_PATH/profiles
	for MODEL in *
	do
		cd $BASE_PATH/profiles
		if [ -d "$MODEL" ] ;then
			shit_happened="No"
			cd $BASE_PATH/profiles/$MODEL/sabores
			for FLAVOR in *
			do
			cd  $BASE_PATH/profiles/$MODEL/sabores
			if [ -d "$FLAVOR" ]; then
				shit_happened_this_time=0
				echo "*Sabor:" $MODEL"-"$FLAVOR
				F_PATH=$SOURCES_PATH"/"$MODEL"-"$FLAVOR
				mkdir -p $F_PATH
				cp -r $MARLIN_TEMPLATE_PATH/* $F_PATH
				mkdir -p $F_PATH"/patches"
				
				cp ../base/* $F_PATH"/patches" &> /dev/null
				cp $FLAVOR/* $F_PATH"/patches" &> /dev/null
				echo "--Aplicando patches y ficheros..."
				cd $F_PATH/Marlin
				for p in `ls ../patches/*.patch`
				do
					cat ../patches/$p | patch -p1
					if [ "$?" -ne 0 ] ; then
						let shit_happened_count++;
						let shit_happened_this_time++;
						echo "ERROR!!! : " $p
					fi
				done
				cd ../patches/
				for file in `ls|grep -v patch`
				do
					echo "----$file"
					cp $file ../Marlin
				done
				if [ $shit_happened_this_time -ne 0 ];then
					echo "Ha fallado la aplicacion de los patches, se elimina de la lista de compilacion"
					rm -rf $F_PATH
				fi
			fi
			done
		fi
	done
	if [ $shit_happened_count -gt 0 ];then
		echo "ha habido errores"
	else
		echo "So far so good!"
	fi
}

compileAllFirmwares()
{
	firmware_count=0
	echo "Compilando firmwares"
	cd $SOURCES_PATH
	for FLAVOR in *
	do
		cd $SOURCES_PATH
		if [ -d "$FLAVOR" ];then
			buildMarlinPath `realpath $FLAVOR` $EXPORT_PATH
			if [ "$?" -eq 0 ];then
				cd $SOURCES_PATH
				RESULT=$EXPORT_PATH/`echo $FLAVOR | awk -F- '{print $1}'`
				echo "Exportando $FLAVOR"
				mkdir -p $RESULT
				cp $EXPORT_PATH/$FLAVOR.hex $RESULT
				cp -r $FLAVOR $RESULT
				let firmware_count++
			else
				let shit_happened_count++
			fi
		fi
	done
	echo "Firmwares:" 		|figlet
	echo $firmware_count 	|figlet
	echo "Errores:" 		|figlet
	echo $shit_happened_count |figlet
	echo "Terminado :)" 	|figlet
}

#Programa

echo "Firmware Factory" | figlet

createDirs

case $1 in
	"setup" )
		sudo apt-get install cmake figlet;;

	"cleanAll" )
		cleanAll;;

	"cleanBuild" )
		cleanBuild;;
		
	"buildTemplate" )
		getFirmwareTemplate
		buildMarlinPath $MARLIN_TEMPLATE_PATH $BUILD_PATH;;

	"prepare" )
		prepareFirmwares;;
		
	"compile" )
		compileAllFirmwares;;
		
	"all" )
		cleanBuild
		getFirmwareTemplate
		prepareFirmwares
		compileAllFirmwares;;
	*)
		echo "Nada que hacer."
esac
