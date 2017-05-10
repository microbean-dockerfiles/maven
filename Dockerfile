FROM microbean/base:8
LABEL maintainer "Laird Nelson <ljnelson@microbean.org>" org.microbean.docker.repository.name="microbean/maven"
RUN yum --assumeyes install gzip tar
WORKDIR /usr/local
RUN curl --silent http://www-us.apache.org/dist/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.tar.gz | tar -zx && \
    ln -s apache-maven-3.5.0 maven && \
    cd bin && \
    ln -s ../maven/bin/mvn mvn
USER microbean
ENV HOME=/home/microbean
WORKDIR ${HOME}
ENV M2_HOME /usr/local/maven
ENV M2_REPO=${HOME}/.m2/repository
RUN mkdir --parents ${M2_REPO} 

ONBUILD RUN mkdir --parents ${HOME}/.microbean/work
ONBUILD COPY . .microbean/work/
ONBUILD WORKDIR ${HOME}/.microbean/work
ONBUILD RUN [ $(ls -1 *.jar 2>/dev/null | wc -l) -eq 1 ] && \
            jarname=$(ls *.jar) && \
            appname=$(basename ${jarname} .jar) && \
            pomxml="$(jar -tf ${jarname} | grep pom.xml$)" && \
            echo ${appname} > ../.application-name && \
            mkdir --parents $(dirname ${pomxml}) && \
            jar -xf "${jarname}" "${pomxml}" && \
            mvn --quiet --batch-mode org.apache.maven.plugins:maven-dependency-plugin:3.0.0:build-classpath --file "${pomxml}" -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -Dmdep.outputFile="${HOME}/.microbean/work/.classpath" -DincludeScope=runtime -Dsilent=true && \
            mvn --quiet --batch-mode org.apache.maven.plugins:maven-install-plugin:2.5.2:install-file -Dfile=${jarname} -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn && \
            sed --in-place "1s;^;$(find ${M2_REPO} -name ${jarname}):;" .classpath && \
            rm --recursive --force META-INF && \
            tar --create --file=.dependencies.tar --transform "s/$(sed 's/^\///;s/\//\\\//g' <<< "${M2_REPO}")\///g" $(tr ':' ' ' < .classpath) && \
            rm --recursive --force ${M2_REPO}/* && \
            tar --extract --directory=${M2_REPO} --file=.dependencies.tar && \
            rm .dependencies.tar && \
            mkdir --parents ${HOME}/.microbean/${appname} && \
            mv .classpath * ${HOME}/.microbean/${appname}
ONBUILD USER root
ONBUILD RUN mv ${HOME}/.microbean/$(<${HOME}/.microbean/.application-name) /etc/opt
ONBUILD USER microbean
ONBUILD WORKDIR ${HOME}
ONBUILD ENTRYPOINT java -cp $(</etc/opt/$(<${HOME}/.microbean/.application-name)/.classpath) org.microbean.main.Main
