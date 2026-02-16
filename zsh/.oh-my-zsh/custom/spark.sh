# BEGIN DATA-ENG-TOOLS MANAGED BLOCK
# Add data-eng-tools binaries and helpers to the path
export PATH="${DATADOG_ROOT}/data-eng-tools/bin:${PATH?}"
[ -f "${DATADOG_ROOT}/data-eng-tools/dotfiles/helpers" ] && source "${DATADOG_ROOT}/data-eng-tools/dotfiles/helpers"
export DYLD_LIBRARY_PATH=/usr/local/opt/openssl/lib
# END DATA-ENG-TOOLS MANAGED BLOCK

# BEGIN DD-ANALYTICS MANAGED BLOCK
# Add required dd-analytics binaries to the path
if [ -z "$LIBRARY_PATH" ]; then
    export LIBRARY_PATH="/opt/homebrew/opt/openssl/lib/"
else
    export LIBRARY_PATH="/opt/homebrew/opt/openssl/lib/:${LIBRARY_PATH?}"
fi

alias j11="export JAVA_HOME=\`/usr/libexec/java_home -v 11\`; java -version"
alias j17="export JAVA_HOME=\`/usr/libexec/java_home -v 17\`; java -version"
alias j21="export JAVA_HOME=\`/usr/libexec/java_home -v 21\`; java -version"

# Set java 11 as default
if /usr/libexec/java_home -v 11 &>/dev/null; then
  export JAVA_HOME=$(/usr/libexec/java_home -v 11)
fi

# For Spark 3.5.2:
export SCALA_HOME="/opt/homebrew/opt/scala@2.12/"
export PATH=$PATH:$SCALA_HOME/bin
export SPARK_HOME=/usr/local/src/spark-3.5.2-bin-hadoop3
export PATH=$PATH:$SPARK_HOME/bin
# Python and Virtualenv Paths
export PATH="/opt/homebrew/opt/virtualenv/bin:$PATH"

# Add dda-cli to the PATH
export PATH=$PATH:${DATADOG_ROOT}/data-eng-tools/bin
# END DD-ANALYTICS MANAGED BLOCK
