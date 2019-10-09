const shell = require('shelljs')
const fail = require('gulp-fail')
const path = require('path')
const fs = require('fs')
const merge = require('merge')
const runSequenceImport = require('run-sequence')

const GROUP_FILE = '.group'
const DEPLOYMENT_FILE = '.deployment'
const PREFIX_FILE = '.prefix'
const LOCATION_FILE = '.location'
const PRODUCT_FILE = '.product'
const PARAMETERS_FILE = 'azuredeploy.parameters.local.json'

const MAIN_TEMPLATE_NAME = 'mainTemplate.json'
const CREATE_UI_DEFINITION_NAME = 'createUiDefinition.json'

const product = function () {
  return shell.test('-f', PRODUCT_FILE) ? shell.cat(PRODUCT_FILE).trim() : 'jira'
}

const GROUP_NAME = product() + '-dc-'

const location = function () {
  return shell.test('-e', LOCATION_FILE) ? shell.cat(LOCATION_FILE).trim() : 'AustraliaEast'
}

const prefix = function () {
  return shell.test('-e', PREFIX_FILE) ? shell.cat(PREFIX_FILE).trim() : ''
}

const current = function () {
  return shell.test('-f', GROUP_FILE) ? parseInt(shell.cat(GROUP_FILE)) : 0
}

const next = function () {
  return current() + 1
}

const nextDeployment = function () {
  return currentDeployment() + 1
}

const currentDeployment = function () {
  return shell.test('-f', DEPLOYMENT_FILE) ? parseInt(shell.cat(DEPLOYMENT_FILE)) : 0
}

function startDeployment (deployment, params, callback) {
  const group = current()
  const deploymentNumber = currentDeployment()
  const cmd = 'az group deployment create'

  if (group) {
    const args = {
      name: `-n "deployment-${deploymentNumber}"`,
      group: `-g ${prefix()}${GROUP_NAME}${group}`,
      template: `--template-file ${deployment}`,
      params: `--parameters @${params}`
    }

    return shell.exec(`${cmd} ${args.name} ${args.group} ${args.template} ${args.params}`, callback)
  }

  throw new Error('No group')
}

async function createDeploymentTask (deployment = getDeploymentPath(), params = getDeploymentParametersPath()) {
  return new Promise((resolve, reject) => startDeployment(deployment, params, (code, stdout, stderr) => {
    if (code !== 0) {
      reject(new Error(stdout + stderr))
    }
    resolve(stdout)
  })).then(result => {
    const createDeployResult = JSON.parse(result)
    fs.writeFileSync('.createDeployResult', result)
    shell.echo(nextDeployment()).to(DEPLOYMENT_FILE)
    return createDeployResult
  })
}

function publish (prepareResources = () => {}, processResources = () => {}, flatten = boolean => true) {
  const pkg = {
    name: product(),
    source: path.join(__dirname, product()),
    target: path.join(__dirname, 'target', product())
  }

  shell.mkdir('-p', pkg.target)

  prepareResources(pkg)

  shell.cp(
    path.resolve(pkg.source, 'mainTemplate.json'),
    path.resolve(pkg.target, MAIN_TEMPLATE_NAME))
  shell.cp(
    path.resolve(pkg.source, 'createUIDefinition.json'),
    path.resolve(pkg.target, CREATE_UI_DEFINITION_NAME))

  processResources(pkg)

  if(flatten) {
    shell.exec([
      'zip', '-r', '--junk-paths',
      path.resolve(pkg.target, '..', `${pkg.name}.zip`),
      pkg.target
    ].join(' '))
  } else {
    shell.exec([
      'pushd '+ pkg.target + ' && ',
      'zip', '-r',
      path.resolve(pkg.target, '..', `${pkg.name}.zip`),
      ".",
      ' && popd',
    ].join(' '))
  }
}

function getDeploymentParametersPath () {
  const override = path.join(__dirname, product(), PARAMETERS_FILE)
  const byDefault = path.join(__dirname, product(), 'azuredeploy.parameters.json')

  if (shell.test('-f', override)) {
    const defaultParameters = JSON.parse(shell.cat(byDefault))
    const overrideParameters = JSON.parse(shell.cat(override))

    const result = merge.recursive(defaultParameters, overrideParameters)
    const output = path.resolve(shell.tempdir(), 'azuredeploy.parameters.json')
    shell.echo(JSON.stringify(result)).to(output)
    return output
  } else {
    return byDefault
  }
}

function getDeploymentPath () {
  return path.join(__dirname, product(), 'mainTemplate.json')
}

function applyTasks (gulp) {
  const runSequence = runSequenceImport.use(gulp)

  gulp.task('check-az-cli', () => {
    if (!shell.which('az')) {
      fail('Unable to find Azure CLI')
    }
  })

  gulp.task('check-zip-cli', () => {
    if (!shell.which('zip')) {
      fail('Unable to find ZIP utility')
    }
  })

  gulp.task('drop-existing-group', ['check-az-cli'], () => {
    const group = current()
    if (group) {
      const { code, stderr } = shell.exec(`az group delete --name ${prefix()}${GROUP_NAME}${group} --no-wait --yes`)
      if (code) {
        fail(stderr)
      }
    }
  })

  gulp.task('create-next-group', ['check-az-cli', 'drop-existing-group'], () => {
    const group = next()
    if (group) {
      const { code, stderr } = shell.exec(`az group create -n ${prefix()}${GROUP_NAME}${group} -l ${location()}`)
      if (code) {
        fail(stderr)
      }
    } else {
      fail('No group')
    }
  })

  gulp.task('create-deployment', ['check-az-cli'], () => createDeploymentTask().catch(e => fail(e)))
  gulp.task('update-group', ['create-next-group'], () => {
    const group = next()
    shell.echo(group).to(GROUP_FILE)
  })
  gulp.task('clean-group', () => {
    shell.rm(GROUP_FILE)
  })

  gulp.task('start', () => runSequence('update-group', 'create-deployment'))
  gulp.task('stop', ['drop-existing-group'])

  gulp.task('publish-jira', () => {
    publish((pkg) => {
      ['scripts', 'templates'].forEach(dir => {
        shell.cp(path.resolve(pkg.source, dir, '*'), pkg.target)
      })
    })
  })

  gulp.task('publish-confluence', () => {
    publish((pkg) => {
      ['scripts', 'templates', 'libs'].forEach(dir => {
        shell.mkdir('-p', path.resolve(pkg.target, dir))
        shell.cp(
          path.resolve(pkg.source, dir, '*'),
          path.resolve(pkg.target, dir))
      })
    })
  })

  gulp.task('publish-bitbucket', () => {
    publish((pkg) => {
      var bitbucketDir = path.resolve(pkg.target, 'bitbucket')
      shell.mkdir('-p', bitbucketDir)
      shell.mkdir('-p', path.resolve(bitbucketDir, 'scripts'))
      shell.cp(
        path.resolve(pkg.source, 'scripts', '*'),
        path.resolve(bitbucketDir, 'scripts'))

      shell.mkdir('-p', path.resolve(bitbucketDir, 'elasticsearch'))
      shell.cp(
        path.resolve(pkg.source, 'elasticsearch', 'elasticsearch.json'),
        path.resolve(bitbucketDir, 'elasticsearch'))
        
      shell.mkdir('-p', path.resolve(bitbucketDir, 'elasticsearch/third-party'))
      shell.cp('-r',
          path.resolve(pkg.source, 'elasticsearch/third-party', '*'),
          path.resolve(bitbucketDir, 'elasticsearch/third-party'))
    }, (pkg) => {
      var mainFileName = pkg.target + '/' + MAIN_TEMPLATE_NAME
      var mainFile = require(mainFileName)

      mainFile.parameters._artifactsLocation.defaultValue = '[deployment().properties.templateLink.uri]'
      delete mainFile.parameters.scriptsBranch
      delete mainFile.parameters.repositoryLocation

      fs.writeFileSync(mainFileName, JSON.stringify(mainFile, null, 2), function (err) {
        if (err) return fail(err)
      })
    }, false)
  })

  gulp.task('publish', () => runSequence('check-zip-cli', `publish-${product()}`))
}

module.exports = { applyTasks, createDeploymentTask, getDeploymentParametersPath, getDeploymentPath }
