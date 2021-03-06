#!/bin/sh

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)
col=$(tput cols)

BASEDIR=$(dirname $0)
NUM_OF_KILO_CALLS=50
#NUM_OF_USERS=25
NUM_OF_USERS=100
NUM_OF_CALLS=$((NUM_OF_KILO_CALLS*1000))
URL=http://127.0.0.1:8080/
JBOSS_EAP_ZIP_FILE=jboss-eap-7.0.0.zip

SPRING_BOOT_ON_JAVASE_URL=http://spring-boot-javase.trafficmanager.net/
SPRING_ON_TOMCAT_URL=http://I01-spring-on-tomcat.trafficmanager.net/
SPRING_ON_WILDFLY_URL=http://I01-spring-on-wildfly.trafficmanager.net/
JAVAEE_ON_WILDFLY_URL=http://I01-javaee-on-wildfly.trafficmanager.net/

function action {
    IFS='%'
    local __actionstr=$1
    local __action=$2
    local __actionstrlenght=${#__actionstr}
    
    printf ${__actionstr}

    let __spaces=${col}-${__actionstrlenght}

    eval ${__action}

    if [ $? -eq 0 ]; then
        printf '%s%*s%s' "$GREEN" $__spaces "[OK]" "$NORMAL"
    else
        printf '%s%*s%s' "$RED" $__spaces "[FAIL]" "$NORMAL"
    fi
    printf "\n"
    
}

function mvn_build_project {
    local __app_name=${1}
    local __project_dir="$BASEDIR/projects/${__app_name}"
    mvn -q -f ${__project_dir}/pom.xml -DskipTests clean package

}

function start_spring_app {
    local __app_name=${1}
    local __app_path="$BASEDIR/projects/${__app_name}/target/${__app_name}.jar"
    java -jar $__app_path > $BASEDIR/spring.log &
    until $(curl -s $URL > /dev/null 2>&1) 
    do
        sleep 1
    done
}

function open_jconsole {
    local __app_name=${1}
    jconsole $(jps -l | grep ${__app_name} | grep -v grep | awk '{ print $1 }') &
}

function install_eap {
    mkdir -p target
    test -d $BASEDIR/target/jboss-eap-7.0 && rm -rf $BASEDIR/target/jboss-eap-7.0    
    unzip -q $BASEDIR/installs/$JBOSS_EAP_ZIP_FILE -d target
    pushd target/jboss-eap-7* > /dev/null
    sh bin/add-user.sh -s -u admin -p admin-123
    sh bin/jboss-cli.sh --commands="embed-server,/subsystem=undertow/configuration=handler/file=welcome-content:remove()" > /dev/null
    popd > /dev/null
}

function start_eap {
    pushd target/jboss-eap-7* > /dev/null
    sh bin/standalone.sh > /dev/null 2>&1 & 
    until $(curl -s $URL > /dev/null 2>&1) 
    do
        sleep 1
    done
    popd > /dev/null
}

function deploy_war {
    local __app_name=${1}
    local __warfile="$BASEDIR/projects/${__app_name}/target/${__app_name}.war"
    local __fullpath_warfile="$(cd $(dirname $__warfile) && pwd)/$(basename $__warfile)"
    pushd target/jboss-eap-7* > /dev/null
    bin/jboss-cli.sh -c --command="deploy $__fullpath_warfile" | grep -iq "success"
    popd > /dev/null
}

function run_springboot {
    local __project="greeting-spring-boot"
    local __app_name=${__project}
    
    action "Build project ${__project}" "mvn_build_project ${__project}"

    action "Waiting for spring boot to start" "start_spring_app ${__project}"

    action "Open Java Console" "open_jconsole ${__app_name}"

    action "Warmup the server" "ab -k -n $NUM_OF_KILO_CALLS -c 1 -s 120 $URL > warmup.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "ab -k -n $NUM_OF_CALLS -c $NUM_OF_USERS -s 120 $URL > performance.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

    action "Stopping the server" "kill $(ps -ef | grep ${__app_name} | grep -v grep | awk '{ print $2 }') > /dev/null"
}

function run_jboss_eap_spring {
    local __project="greeting-spring"
    local __app_name="jboss-eap"
    
    action "Building project ${__project}" "mvn_build_project ${__project}"

    action "Installing JBoss EAP" "install_eap"

    action "Start JBoss EAP" "start_eap"

    action "Deploying the ${__project}.war to JBoss EAP" "deploy_war ${__project}"

    action "Open Java Console" "open_jconsole ${__app_name}"

    action "Warmup the server" "ab -k -n $NUM_OF_KILO_CALLS -c 1 -s 120 $URL > warmup.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "ab -k -n $NUM_OF_CALLS -c $NUM_OF_USERS -s 120 $URL > performance.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

    action "Stopping the server" "kill $(jps -l | grep ${__app_name} | grep -v grep | awk '{ print $1 }') > /dev/null"
}

function run_jboss_eap_javaee {
    local __project="greeting-javaee"
    local __app_name="jboss-eap"

    action "Building project ${__project}" "mvn_build_project ${__project}"

    action "Installing JBoss EAP" "install_eap"

    action "Start JBoss EAP" "start_eap"

    action "Deploying the ${__project}.war to JBoss EAP" "deploy_war ${__project}"

    action "Open Java Console" "open_jconsole ${__app_name}"

    action "Warmup the server" "ab -k -n $NUM_OF_KILO_CALLS -c 1 -s 120 $URL > warmup.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "ab -k -n $NUM_OF_CALLS -c $NUM_OF_USERS -s 120 $URL > performance.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

    action "Stopping the server" "kill $(jps -l | grep ${__app_name} | grep -v grep | awk '{ print $1 }') > /dev/null"

}

function run_springboot_on_javase_azure {

    action "Warming up the server" "wrk -t12 -c400 -d300s --latency ${SPRING_BOOT_ON_JAVASE_URL} > warmup-spring-on-javase.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "wrk -t12 -c400 -d600s --latency ${SPRING_BOOT_ON_JAVASE_URL} > performance-spring-on-javase.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

}

function run_spring_on_tomcat_azure {

    action "Warming up the server" "wrk -t12 -c400 -d300s --latency ${SPRING_ON_TOMCAT_URL} > warmup-spring-on-tomcat.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "wrk -t12 -c400 -d600s --latency ${SPRING_ON_TOMCAT_URL} > performance-spring-on-tomcat.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

}

function run_spring_on_wildfly_azure {

    action "Warming up the server" "wrk -t12 -c400 -d300s --latency ${SPRING_ON_WILDFLY_URL} > warmup-spring-on-wildfly.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "wrk -t12 -c400 -d600s --latency ${SPRING_ON_WILDFLY_URL} > performance-spring-on-wildfly.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

}

function run_javaee_on_wildfly_azure {

    action "Warming up the server" "wrk -t12 -c400 -d300s --latency ${JAVAEE_ON_WILDFLY_URL} > warmup-javaee-on-wildfly.txt 2>&1"

    action "Waiting for the warmup to cool off" "sleep 10"

    action "Running performance test" "wrk -t12 -c400 -d600s --latency ${JAVAEE_ON_WILDFLY_URL} > performance-javaee-on-wildfly.txt 2>&1"

    action "Waiting for the performance test to cool off" "sleep 30"

}

function help {
        local command_name="run.sh"
        echo "Valid commands:"
        echo "$command_name spring-boot"
        echo "$command_name jws"
        echo "$command_name jboss-eap-spring"
        echo "$command_name jboss-eap-javaee"
        echo "$command_name spring-boot-on-javase-azure"
        echo "$command_name spring-on-tomcat-azure"
        echo "$command_name spring-on-wildfly-azure"
        echo "$command_name javaee-on-wildfly-azure"
        echo "$command_name kill-all"
}

function not_implemented_yet {
    echo "This feature has not been implemented yet"
}

if [[ $# -gt 0 ]]
then
   key="$1"
   case $key in
      spring-boot)
        shift # past argument
        run_springboot "$@"
        ;;
      jws)
        shift # past argument
        not_implemented_yet
        ;;
      jboss-eap-spring)
        shift # past argument
        run_jboss_eap_spring "$@"
        ;;
      jboss-eap-javaee)
        shift # past argument
        run_jboss_eap_javaee "$@"
        ;;
      spring-boot-on-javase-azure)
        shift # past argument
        run_springboot_on_javase_azure "$@"
        ;;
      spring-on-tomcat-azure)
        shift # past argument
        run_spring_on_tomcat_azure "$@"
        ;;
      spring-on-wildfly-azure)
        shift # past argument
        run_spring_on_wildfly_azure "$@"
        ;;
      javaee-on-wildfly-azure)
        shift # past argument
        run_javaee_on_wildfly_azure "$@"
        ;;
      kill-all)
        shift # past argument
        not_implemented_yet
        ;;
      *)
        # unknown option
        echo "Unknown option. Show help"
        help
        ;;
   esac
else
   help
fi