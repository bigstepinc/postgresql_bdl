FROM ubuntu:16.04

ADD entrypoint.sh /
ADD password.py /opt/
ADD env.sh /opt/
ADD handlers.py /opt/

# Install Java 8
ENV JAVA_HOME /opt/jdk1.8.0_181
ENV PATH $PATH:/opt/jdk1.8.0_181/bin:/opt/jdk1.8.0_181/jre/bin:/etc/alternatives:/var/lib/dpkg/alternatives

RUN apt-get -qq update -y
RUN apt-get install -y unzip wget curl tar bzip2 software-properties-common git

RUN cd /opt && wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-linux-x64.tar.gz" &&\
   tar xzf jdk-8u181-linux-x64.tar.gz && rm -rf jdk-8u181-linux-x64.tar.gz

RUN echo 'export JAVA_HOME="/opt/jdk1.8.0_181"' >> ~/.bashrc && \
    echo 'export PATH="$PATH:/opt/jdk1.8.0_181/bin:/opt/jdk1.8.0_181/jre/bin"' >> ~/.bashrc && \
    bash ~/.bashrc && cd /opt/jdk1.8.0_181/ && update-alternatives --install /usr/bin/java java /opt/jdk1.8.0_181/bin/java 1
    
#Add Java Security Policies
RUN curl -L -C - -b "oraclelicense=accept-securebackup-cookie" -O http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip && \
   unzip jce_policy-8.zip
RUN cp UnlimitedJCEPolicyJDK8/US_export_policy.jar /opt/jdk1.8.0_181/jre/lib/security/ && cp UnlimitedJCEPolicyJDK8/local_policy.jar /opt/jdk1.8.0_181/jre/lib/security/
RUN rm -rf UnlimitedJCEPolicyJDK8

ENV R_LIBS_USER /opt/conda/envs/ir/lib/R/library:/opt/conda/lib/R/library

# Create additional files in the DataLake
RUN mkdir -p /user && mkdir -p /user/notebooks && mkdir -p /user/datasets && chmod 777 /entrypoint.sh

# Setup Miniconda
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH

RUN cd /opt && \
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh && \ 
    /bin/bash Miniconda3-latest-Linux-x86_64.sh  -b -p $CONDA_DIR && \
     rm -rf Miniconda3-latest-Linux-x86_64.sh

RUN export PATH=$PATH:$CONDA_DIR/bin

# Install Jupyter notebook 
RUN $CONDA_DIR/bin/conda install --yes \
    'notebook' && \
    $CONDA_DIR/bin/conda clean -yt
    
RUN $CONDA_DIR/bin/jupyter notebook  --generate-config --allow-root

RUN $CONDA_DIR/bin/conda install -c conda-forge nb_conda
RUN $CONDA_DIR/bin/python -m nb_conda_kernels.install --disable --prefix=$CONDA_DIR && \
    $CONDA_DIR/bin/conda clean -yt

#Install Scala Spark kernel
ENV SBT_VERSION 0.13.11
ENV SBT_HOME /usr/local/sbt
ENV PATH ${PATH}:${SBT_HOME}/bin
    
#Install Python3 packages
RUN cd /root && $CONDA_DIR/bin/conda install --yes \
    'ipywidgets' \
    'pandas' \
    'matplotlib' \
    'scipy' \
    'seaborn' \
    'scikit-learn' && \
    $CONDA_DIR/bin/conda clean -yt
    
RUN $CONDA_DIR/bin/conda config --set auto_update_conda False

RUN CONDA_VERBOSE=3 $CONDA_DIR/bin/conda create --yes -p $CONDA_DIR/envs/python3 python=3.5 ipython ipywidgets pandas matplotlib scipy seaborn scikit-learn
RUN bash -c '. activate $CONDA_DIR/envs/python3 && \
    python -m ipykernel.kernelspec --prefix=/opt/conda && \
    . deactivate'
    
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O /root/jq-linux64

RUN chmod +x /root/jq-linux64
RUN /root/jq-linux64 --arg v "$CONDA_DIR/envs/python3/bin/python"         '.["env"]["PYSPARK_PYTHON"]=$v' /opt/conda/share/jupyter/kernels/python3/kernel.json > /tmp/kernel.json &&   \
    mv /tmp/kernel.json /opt/conda/share/jupyter/kernels/python3/kernel.json

#Install R kernel and set up environment
RUN $CONDA_DIR/bin/conda config --add channels r
RUN $CONDA_DIR/bin/conda install --yes -c r r-essentials r-base r-irkernel r-irdisplay r-ggplot2 r-repr r-rcurl
RUN $CONDA_DIR/bin/conda create --yes  -n ir -c r r-essentials r-base r-irkernel r-irdisplay r-ggplot2 r-repr r-rcurl

#Configure Scala kernel
RUN mkdir -p /opt/conda/share/jupyter/kernels/scala
COPY kernel.json /opt/conda/share/jupyter/kernels/scala/

#Add Getting Started Notebooks and change Jupyter logo and download additional libraries
RUN wget http://repo.uk.bigstepcloud.com/bigstep/datalab/datalab_getting_started_in_scala__4.ipynb -O /user/notebooks/DataLab\ Getting\ Started\ in\ Scala.ipynb && \
   wget http://repo.bigstepcloud.com/bigstep/datalab/DataLab%2BGetting%2BStarted%2Bin%2BR%20%281%29.ipynb -O /user/notebooks/DataLab\ Getting\ Started\ in\ R.ipynb && \
   wget http://repo.bigstepcloud.com/bigstep/datalab/DataLab%2BGetting%2BStarted%2Bin%2BPython%20%283%29.ipynb -O /user/notebooks/DataLab\ Getting\ Started\ in\ Python.ipynb && \
   wget http://repo.bigstepcloud.com/bigstep/datalab/logo.png -O logo.png && \
   cp logo.png $CONDA_DIR/envs/python3/doc/global/template/images/logo.png && \
   cp logo.png $CONDA_DIR/envs/python3/lib/python3.5/site-packages/notebook/static/base/images/logo.png && \
   cp logo.png $CONDA_DIR/doc/global/template/images/logo.png && \
   rm -rf logo.png 
   
RUN apt-get install -y libcairo3-dev  python3-cairo-dev

RUN cd /tmp && \
    wget "http://repo.bigstepcloud.com/bigstep/datalab/sbt-0.13.11.tgz" -O /tmp/sbt-0.13.11.tgz && \
    tar -xvf /tmp/sbt-0.13.11.tgz -C /usr/local && \
    echo -ne "- with sbt $SBT_VERSION\n" >> /root/.built && \
    git clone https://github.com/apache/incubator-toree.git && \
    cd incubator-toree && \
    git checkout cc8bf2a561d87c289981298ab594d2ea851ad1ed && \
    make dist SHELL=/bin/bash APACHE_SPARK_VERSION=2.3.0 SCALA_VERSION=2.11 && \
    mv /tmp/incubator-toree/dist/toree /opt/toree-kernel && \
    chmod +x /opt/toree-kernel && \
    rm -rf /tmp/incubator-toree && \
    wget http://repo.bigstepcloud.com/bigstep/datalab/toree-assembly-0.3.0.dev1-incubating-SNAPSHOT.jar -O /opt/toree-kernel/lib/toree-assembly-0.3.0.dev1-incubating-SNAPSHOT.jar && \
    cd /opt/ && \
    wget http://repo.uk.bigstepcloud.com/bigstep/datalab/datalake-1.5-SNAPSHOT-bin.tar.gz && \
    tar xzvf datalake-1.5-SNAPSHOT-bin.tar.gz && \
    rm -rf datalake-1.5-SNAPSHOT-bin.tar.gz && \
    export PATH=$PATH:/opt/datalake-1.5-SNAPSHOT/bin
    
#        Jupyter 
EXPOSE   8888     

ENTRYPOINT ["/entrypoint.sh"]
