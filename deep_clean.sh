#!/bin/bash

echo "This will clean all layers, builds and sstate CTRL+c to abort"

read -n 1

echo "Deep clean start...."

for n in $(ls -d1 sstate-cache) ; do
 echo "cleaning $n" 
 rm -Rf $n
done


for n in $(ls -d1 build_*) ; do
 echo "cleaning $n"
 rm -Rf $n
done

for n in $(ls -d1 meta-*) ; do
 
  if [ "$n" = "meta-composeos" ] ; then 
     echo "composeos layer not cleaned"
     continue
  fi
  if [ -L $n ] ; then 
     echo "layer $n is link --> not cleanded"
     continue
  fi 
  echo "cleaning $n"
  rm -Rf $n
done

echo "clean poky..."
rm -Rf poky

echo "done"

