#!/bin/bash

export JAVA_HOME="/opt/jdk1.8.0_181/"                                                                                                                               
export PATH="$PATH:/opt/jdk1.8.0_181/bin:/opt/jdk1.8.0_181/jre/bin:/opt/hadoop/bin/:/opt/hadoop/sbin/"
export JAVA_CLASSPATH="$JAVA_HOME/jre/lib/"
export JAVA_OPTS="-Dsun.security.krb5.debug=true -XX:MetaspaceSize=128M -XX:MaxMetaspaceSize=256M"

if [ "$SPARK_MASTER_PORT" == "" ]; then
  SPARK_MASTER_PORT=7077
fi
if [ "$SPARK_UI_PORT" == "" ]; then
  SPARK_UI_PORT=4040
fi
if [ "$SPARK_MASTER_HOSTNAME" == "" ]; then
  SPARK_MASTER_HOSTNAME=`hostname -f`
fi

if [ "$NOTEBOOK_DIR" != "" ]; then
	export ESCAPED_PERSISTENT_NB_DIR="${NOTEBOOK_DIR//\//\\/}"
	
	mkdir $PERSISTENT_NB_DIR/notebooks
	cp /user/notebooks/* $PERSISTENT_NB_DIR/notebooks/

	sed "s/#c.NotebookApp.notebook_dir = u.*/c.NotebookApp.notebook_dir = u\'$ESCAPED_PERSISTENT_NB_DIR\/notebooks\'/" /root/.jupyter/jupyter_notebook_config.py >> /root/.jupyter/jupyter_notebook_config.py.tmp
	mv /root/.jupyter/jupyter_notebook_config.py.tmp /root/.jupyter/jupyter_notebook_config.py
	
fi

if [ "$MODE" == "" ]; then
MODE=$1
fi

if [ "$MODE" == "jupyter" ]; then 
	# Change the Home Icon 
	sed "s/<i class=\"fa fa-home\"><\/i>/\/user/" /opt/conda/envs/python3/lib/python3.5/site-packages/notebook/templates/tree.html >> /opt/conda/envs/python3/lib/python3.5/site-packages/notebook/templates/tree.html.tmp
	mv /opt/conda/envs/python3/lib/python3.5/site-packages/notebook/templates/tree.html.tmp /opt/conda/envs/python3/lib/python3.5/site-packages/notebook/templates/tree.html
	
	export NOTEBOOK_PASSWORD=$(cat $SPARK_SECRETS_PATH/NOTEBOOK_PASSWORD)

	pass=$(python /opt/password.py  $NOTEBOOK_PASSWORD)
	sed "s/#c.NotebookApp.password = u.*/c.NotebookApp.password = u\'$pass\'/" /root/.jupyter/jupyter_notebook_config.py >> /root/.jupyter/jupyter_notebook_config.py.tmp && \
	mv /root/.jupyter/jupyter_notebook_config.py.tmp /root/.jupyter/jupyter_notebook_config.py

	if [ "$GIT_REPO_NAME" != "" ]; then
		if [ "$GITHUB_COMMIT_DIR" == "" ]; then 
			export GITHUB_COMMIT_DIR=/opt
		fi
		if [ "$GIT_PARENT_DIR" == "" ]; then 
			export GIT_PARENT_DIR=$PERSISTENT_NB_DIR
		fi
		if [ "$GIT_BRANCH_NAME" == "" ]; then 
			export GIT_BRANCH_NAME=master
		fi
		if [[ "$GIT_USER" != "" && "$GIT_EMAIL" != "" && "$GITHUB_ACCESS_TOKEN" != "" ]]; then 
			if [ "$GIT_USER_UPSTREAM" == "" ]; then 
				export GIT_USER_UPSTREAM=$GIT_USER
			fi
		
			pip install git+https://github.com/sat28/githubcommit.git
			jupyter serverextension enable --py githubcommit
			jupyter nbextension install --py githubcommit
			jupyter nbextension enable githubcommit --py
		
			cd $GITHUB_COMMIT_DIR && git clone https://github.com/sat28/githubcommit
			rm -rf $GITHUB_COMMIT_DIR/githubcommit/env.sh
			mv /opt/env.sh $GITHUB_COMMIT_DIR/githubcommit/
		
			sed "s/GITHUB_COMMIT_DIR=/GITHUB_COMMIT_DIR=$GITUB_COMMIT_DIR/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_PARENT_DIR=/GIT_PARENT_DIR=$GIT_PARENT_DIR/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_REPO_NAME=/GIT_REPO_NAME=$GIT_REPO_NAME/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_BRANCH_NAME=/GIT_BRANCH_NAME=$GIT_BRANCH_NAME/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_USER=/GIT_USER=$GIT_USER/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_EMAIL=/GIT_EMAIL=$GIT_EMAIL/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GITHUB_ACCESS_TOKEN=/GITHUB_ACCESS_TOKEN=$GITHUB_ACCESS_TOKEN/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			sed "s/GIT_USER_UPSTREAM=/GIT_USER_UPSTREAM=$GIT_USER_UPSTREAM/" $GITHUB_COMMIT_DIR/githubcommit/env.sh >> $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp && \
			mv $GITHUB_COMMIT_DIR/githubcommit/env.sh.tmp $GITHUB_COMMIT_DIR/githubcommit/env.sh
		
			git config --global user.email "$GIT_EMAIL"
			git config --global user.name "$GIT_USER"
		
			source $GITHUB_COMMIT_DIR/githubcommit/env.sh
			cd $GIT_PARENT_DIR/$GIT_REPO_NAME && \
			git config remote.master.url https://$GIT_USER:$GIT_ACCESS_TOKEN@github.com/$GIT_USER/$GIT_REPO_NAME.git
		
			rm -rf $CONDA_DIR/lib/python2.7/site-packages/githubcommit/handlers.py
			mv /opt/env.sh $CONDA_DIR/lib/python3/site-packages/githubcommit/
		fi
	fi

	#Install sparkmonitor extension
	export SPARKMONITOR_UI_HOST=$SPARK_PUBLIC_DNS
	export SPARKMONITOR_UI_PORT=$SPARK_UI_PORT

	pip install https://github.com/krishnan-r/sparkmonitor/releases/download/v0.0.1/sparkmonitor.tar.gz #Use latest version as in github releases

	jupyter nbextension install sparkmonitor --py --user --symlink 
	jupyter nbextension enable sparkmonitor --py --user            
	jupyter serverextension enable --py --user sparkmonitor

	#ipython profile create && echo "c.InteractiveShellApp.extensions.append('sparkmonitor')" >>  $(ipython profile locate default)/ipython_kernel_config.py
	ipython profile create && echo "c.InteractiveShellApp.extensions.append('sparkmonitor.kernelextension')" >> $(ipython profile locate default)/ipython_kernel_config.py
fi


if [ "$MODE" == "jupyter" && "$SPARK_PUBLIC_DNS" == "" ]; then 
	jupyter notebook --ip=0.0.0.0 --log-level DEBUG --allow-root --NotebookApp.iopub_data_rate_limit=10000000000 
else
	jupyter notebook --ip=0.0.0.0 --log-level DEBUG --allow-root --NotebookApp.iopub_data_rate_limit=10000000000 --Spark.url="http://$SPARK_PUBLIC_DNS:$SPARK_UI_PORT"
fi
