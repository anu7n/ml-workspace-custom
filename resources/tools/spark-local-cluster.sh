#!/bin/bash

# Stops script execution if a command has an error
set -e

INSTALL_ONLY=0
# Loop through arguments and process them: https://pretzelhands.com/posts/command-line-flags
for arg in "$@"; do
    case $arg in
        -i|--install) INSTALL_ONLY=1 ; shift ;;
        *) break ;;
    esac
done

# Script inspired by: https://github.com/jupyter/docker-stacks/blob/master/pyspark-notebook/Dockerfile#L18
# https://github.com/apache/incubator-toree/blob/master/Dockerfile

# Install scala 2.12
if [[ ! $(scala -version 2>&1) =~ "version 2.12" ]]; then
    # Update to Scala 2.12 is required for spark
    SCALA_VERSION=2.12.12
    echo "Updating to Scala $SCALA_VERSION. Please wait..."
    apt-get remove scala-library scala
    apt-get autoremove
    wget -q https://downloads.lightbend.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.deb -O ./scala.deb
    dpkg -i scala.deb
    rm scala.deb
    apt-get update
    apt-get install scala
else
    echo "Scala 2.12 already installed."
fi

export SPARK_HOME=/opt/spark

if [ ! -d "$SPARK_HOME" ]; then
    echo "Installing Spark. Please wait..."
    cd $RESOURCES_PATH
    SPARK_VERSION="3.0.1"
    HADOOP_VERSION="3.2"
    wget https://mirror.checkdomain.de/apache/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz -O ./spark.tar.gz
    tar xzf spark.tar.gz
    mv spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION/ $SPARK_HOME
    rm spark.tar.gz

    # create spark events dir
    mkdir -p /tmp/spark-events

    # Create empty spark config file
    printf "" > $SPARK_HOME/conf/spark-defaults.conf

    # Install Sparkmagic: https://github.com/jupyter-incubator/sparkmagic
    apt-get update
    apt-get install -y libkrb5-dev
    pip install --no-cache-dir sparkmagic
    jupyter serverextension enable --py sparkmagic

    # Install sparkmonitor: https://github.com/krishnan-r/sparkmonitor
    pip install --no-cache-dir sparkmonitor
    jupyter nbextension install sparkmonitor --py --sys-prefix --symlink
    jupyter nbextension enable sparkmonitor --py --sys-prefix
    jupyter serverextension enable --py --sys-prefix sparkmonitor
    ipython profile create && echo "c.InteractiveShellApp.extensions.append('sparkmonitor.kernelextension')" >>  $(ipython profile locate default)/ipython_kernel_config.py

    # Deprecated: jupyter-spark: https://github.com/mozilla/jupyter-spark
    # jupyter serverextension enable --py jupyter_spark && \
    # jupyter nbextension install --py jupyter_spark && \
    # jupyter nbextension enable --py jupyter_spark && \
    # python -m spylon_kernel install
    # Install Jupyter kernels
    # Install beakerX? https://github.com/twosigma/beakerx
    # link spark folder to /usr/local/spark
    # ln -s /usr/local/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /usr/local/spark && \
else
    echo "Spark is already installed"
fi

export PATH=$PATH:$SPARK_HOME/bin

# Install python dependencies
pip install --no-cache-dir pyspark findspark pyarrow spylon-kernel
# downgrades sklearn: spark-sklearn \

# Install Apache Toree Kernel: https://github.com/apache/incubator-toree
if [[ ! $(jupyter kernelspec list) =~ "toree" ]]; then
    echo "Installing Toree Kernel for Jupyter. Please wait..."
    TOREE_VERSION=0.5.0
    pip install --no-cache-dir https://dist.apache.org/repos/dist/dev/incubator/toree/$TOREE_VERSION-incubating-rc1/toree-pip/toree-$TOREE_VERSION.tar.gz
    jupyter toree install --sys-prefix --spark_home=$SPARK_HOME
else
    echo "Toree Kernel for Jupyter is already installed."
fi


# TODO: Install R Spark integration
# wget -q https://www.apache.org/dyn/closer
# ENV R_LIBS_USER $SPARK_HOME/R/lib

#RUN conda install --yes 'r-sparklyr' && \
    # Cleanup
#    clean-layer.sh

# Run
if [ $INSTALL_ONLY = 0 ] ; then
    if [ -z "$PORT" ]; then
        read -p "Please provide a port for starting a local Spark cluster: " PORT
    fi

    echo "Starting local Spark cluster on port "$PORT
    echo "spark.ui.proxyBase /tools/"$PORT >> $SPARK_HOME/conf/spark-defaults.conf;

    $SPARK_HOME/sbin/stop-master.sh
    $SPARK_HOME/sbin/start-master.sh --webui-port $PORT
    echo "Spark cluster is started. To access the dashboard, use the link in the open tools menu."
    echo '{"id": "spark-link", "name": "Spark", "url_path": "/tools/'$PORT'/", "description": "Apache Spark Dashboard"}' > $HOME/.workspace/tools/spark.json
    sleep 20
fi
