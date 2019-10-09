import re
from os import environ
import sys


def get_parameters(env_variables):
  parameters = {}
  for env_var in env_variables:
    ev_value = environ.get(env_var, '')
    parameters[env_var] = ev_value
  return parameters


def process_line(pattern, line, parameters):
  matches = pattern.findall(line)
  if not matches:
    return line

  for parameter in matches:
    substitution = parameters.get(parameter, None)
    if substitution:
      line = line.replace('{{%s}}' % parameter, substitution)

  return line


def main():
  confluence_config_xml_env_variables = [
        'APPLICATION_TITLE',
        'ATL_CONFLUENCE_INSTALL_DIR',
        'ATL_CONFLUENCE_SHARED_HOME',
        'CONFLUENCE_C3P0_MAX_SIZE',
        'CONFLUENCE_C3P0_MIN_SIZE',
        'CONFLUENCE_CLUSTER_INTERFACE_NAME',
        'CONFLUENCE_CLUSTER_PEERS',
        'CONFLUENCE_GC_OPTS',
        'CONFLUENCE_HTTP_CONNECTOR_CONNECTION_TIMEOUT',
        'CONFLUENCE_HTTP_CONNECTOR_DISABLE_UPLOAD_TIMEOUT',
        'CONFLUENCE_HTTP_CONNECTOR_MAX_ACCEPT_COUNT',
        'CONFLUENCE_HTTP_CONNECTOR_MAX_HEADER_SIZE',
        'CONFLUENCE_HTTP_CONNECTOR_MAX_THREADS',
        'CONFLUENCE_HTTP_CONNECTOR_MIN_THREADS',
        'CONFLUENCE_JWT_PRIVATE_KEY',
        'CONFLUENCE_JWT_PUBLIC_KEY',
        'CONFLUENCE_LICENSE',
        'CONFLUENCE_MEMORY_MAX',
        'CONFLUENCE_PRELOAD_DARKFEATURES',
        'CONFLUENCE_SQLSERVER_DATABASE_COMPATIBILITY_LEVEL',
        'DB_NAME',
        'DB_PASSWORD',
        'DB_SCHEMA',
        'DB_SERVER_NAME',
        'DB_TRUSTED_HOST',
        'DB_USER',
        'DB_PORT',
        'DB_TYPE',
        'DB_JDBCURL',
        'DB_DRIVER_CLASS',
        'DB_DRIVER_DIALECT',
        'DB_CONFIG_TYPE',
        'EXTRA_CONFLUENCE_JAVA_OPTS',
        'SERVER_APP_PORT',
        'SERVER_APP_SCHEME',
        'SERVER_CLUSTER_NAME',
        'SERVER_ID',
        'SERVER_PROXY_NAME',
        'SERVER_PROXY_PORT',
        'SERVER_SECURE_FLAG',
        'USER_EMAIL',
        'USER_EMAIL_LOWERCASE',
        'USER_FIRSTNAME',
        'USER_FIRSTNAME_LOWERCASE',
        'USER_LASTNAME',
        'USER_LASTNAME_LOWERCASE',
        'USER_NAME',
        'USER_NAME_LOWERCASE',
        'USER_PASSWORD',
        'USER_FULLNAME',
        'USER_FULLNAME_LOWERCASE',
        'DB_SCRIPT_NAME_LOC',
        'APPINSIGHTS_VER',
        'APPINSIGHTS_INSTRUMENTATION_KEY'
  ]
  ##
  ## cat templates/*.template | sed "s#{{#~{{#g" |sed "s#}}#}}~#g" | tr '~' '\n' | grep "{{" | sed "s#{{##" | sed "s#}}.*##" | sort | uniq | sed "s/^/'/" | sed "s/$/',/"
  ##
  env_variables = ( confluence_config_xml_env_variables )

  parameters = get_parameters(env_variables)
  parameter_pattern = re.compile(r"\{\{([a-zA-Z0-9\._]*)\}\}")

  for line in sys.stdin:
    transformed_line = process_line(parameter_pattern, line, parameters)
    sys.stdout.write(transformed_line)


if __name__ == '__main__':
  main()
