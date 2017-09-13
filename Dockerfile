FROM centos:7
MAINTAINER jdcasey@commonjava.org

RUN yum -y update \
    && yum -y install java-1.8.0-openjdk-devel git which iproute bzip2 \
    && yum clean all \
    && useradd maven

ADD http://apache.osuosl.org/maven/maven-3/3.5.0/binaries/apache-maven-3.5.0-bin.tar.gz /tmp/maven.tar.gz

RUN tar -zxvf /tmp/maven.tar.gz -C /home/maven 
RUN rm /tmp/maven.tar.gz
RUN mv /home/maven/apache-maven-3.5.0 /home/maven/apache-maven
RUN chown -R maven /home/maven/apache-maven
RUN ls -l /home/maven/apache-maven/lib
RUN mkdir /home/maven/bin
RUN chown -R maven /home/maven/bin

ADD bin/run-release.sh /home/maven/bin/run-release.sh

VOLUME ["/home/maven/.m2", "/home/maven/.ssh", "/home/maven/.gnupg"]
USER maven:maven
WORKDIR /home/maven

ENV GIT_BRANCH master
ENV GIT nothing

ENTRYPOINT ["/home/maven/bin/run-release.sh"]

