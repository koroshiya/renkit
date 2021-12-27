# RenKit

A collection of tools to help you organise and use Ren'Py instances from the command line. Especially useful for headless servers.

RenKit consists of three tools:
1. `renutil` manages Ren'Py instances and takes care of installing, launching and removing them.
2. `renotize` is a macOS-exclusive tool which notarizes built distributions of Ren'Py games for macOS.
3. `renconstruct` automates the build process for Ren'Py games start to finish.

RenKit is written in Nim and compiled into standalone executables, so it's easy to use anywhere. Currently it supports the three main platforms, Windows, Linux and macOS on x86.

## renutil

### List all installed versions
```bash
renutil list
```

### List all remote versions
```bash
renutil list -a
```

### Show information about a specific version
```bash
renutil show -v 7.4.11
```

### Launch the Ren'Py Launcher
```bash
renutil launch -v 7.4.11
```

### Launch a Ren'Py project directly
```bash
renutil launch -v 7.4.11 -d -a ~/my-project
```

### Install a specific version
```bash
renutil install -v 7.4.11
```

### Remove a specific version
```bash
renutil uninstall -v 7.4.11
```

### Clean up an instance after use
```bash
renutil clean -v 7.4.11
```

### Full Usage
```bash
Usage is like:
    renutil {SUBCMD} [subcommand-opts & args]
where subcommand syntaxes are as follows:

  list [optional-params]
    List all available versions of RenPy, either local or remote.
  Options:
      -n=, --n=         int     0      The number of items to show. Shows all by default.
      -a, --all         bool    false  If given, shows remote versions.
      -r=, --registry=  string  ""     The registry to use. Defaults to ~/.renutil

  show [required&optional-params]
    Show information about a specific version of RenPy.
  Options:
      -v=, --version=   string  REQUIRED  The version to show.
      -r=, --registry=  string  ""        The registry to use. Defaults to ~/.renutil

  launch [required&optional-params]
    Launch the given version of RenPy.
  Options:
      -v=, --version=   string  REQUIRED  The version to launch.
      --headless        bool    false     If given, disables audio and video drivers for headless operation.
      -d, --direct      bool    false     If given, invokes RenPy directly without the launcher project.
      -a=, --args=      string  ""        The arguments to forward to RenPy.
      -r=, --registry=  string  ""        The registry to use. Defaults to ~/.renutil

  install [required&optional-params]
    Install the given version of RenPy.
  Options:
      -v=, --version=   string  REQUIRED  The version to install.
      -r=, --registry=  string  ""        The registry to use. Defaults to ~/.renutil
      -n, --no-cleanup  bool    false     If given, retains installation files.
      -f, --force       bool    false     set force

  cleanup [required&optional-params]
    Cleans up temporary directories for the given version of RenPy.
  Options:
      -v=, --version=   string  REQUIRED  The version to clean up.
      -r=, --registry=  string  ""        The registry to use. Defaults to ~/.renutil

  uninstall [required&optional-params]
    Uninstalls the given version of RenPy.
  Options:
      -v=, --version=   string  REQUIRED  The version to uninstall.
      -r=, --registry=  string  ""        The registry to use. Defaults to ~/.renutil
```

## renconstruct

### Writing a config file
renconstruct uses a TOML file for configuration to supply the information required to complete the build process for the various platforms. An empty template is provided in this repository under the name `renconstruct.config.empty.toml`

It consists of the following sections:

#### `tasks`
Each of these keys may have a value of `true` or `false`.

- `clean`: Enables the cleanup task, which cleans up temporary files after the build has completed
- `notarize`: Enables the notarization task
- `keystore`: Enables the keystore override task

#### `task_keystore`
- `keystore_apk`: The base-64 encoded binary keystore file for the APK bundles
- `keystore_aab`: The base-64 encoded binary keystore file for the AAB bundles

#### `task_notarize`
Same as the configuration for `renotize` below.

- `apple_id`: The e-Mail address belonging to the Apple ID you want to use for signing applications.
- `password`: An app-specific password generated through the [management portal](https://appleid.apple.com/account/manage) of your Apple ID.
- `identity`: The identity associated with your Developer Certificate which can be found in `Keychain Access` under the category "My Certificates". It starts with `Developer ID Application:`, however it suffices to provide the 10-character code in the title of the certificate.
- `bundle`: The internal name for your app. This is typically the reverse domain notation of your website plus your application name, i.e. `com.example.mygame`.
- `altool_extra`: An optional string that will be passed on to all `altool` runs in all commands. Useful for selecting an organization when your Apple ID belongs to multiple, for example. Typically you will not have to touch this and you can leave it empty.

#### `build`
Each of these keys may have a value of `true` or `false`.

_ `pc`: Build the Windows/Linux  distribution
- `win`: Build the Windows distribution
- `mac`: Build the macOS distribution
_ `web`: Build the Web distribution
_ `steam`: Build the Steam distribution
_ `market`: Build the external marketplace distribution (i.e. Itch.io)
- `android_apk`: Build the Android distribution as an APK
- `android_aab`: Build the Android distribution as an AAB

#### `options`
- `clear_output_dir`: A value of `true` or `false` determining whether to clear the output directory on invocation or not. Useful for repeated runs where you want to persist previous results.

#### `renutil`
- `version`: The version of Ren'Py to use while building the distributions
- `registry`: The path where `renutil` data is stored. Mostly useful for CI environments

### Build a set of distributions
```bash
renconstruct build -i ~/my-project -o out/ -c my-config.toml
```

### Full Usage
```bash
Usage is like:
    renconstruct {SUBCMD} [subcommand-opts & args]
where subcommand syntaxes are as follows:

  build [required&optional-params]
    Builds a RenPy project with the specified configuration.
  Options:
      -i=, --input_dir=   string  REQUIRED  The RenPy project to build.
      -o=, --output_dir=  string  REQUIRED  The directory to output distributions to.
      -c=, --config=      string  REQUIRED  The configuration file to use.
      -r=, --registry=    string  ""        The registry to use. Defaults to ~/.renutil
```

## renotize

### Writing a config file
renotize uses a TOML file for configuration to supply the information required to sign apps on macOS. An empty template is provided in this repository under the name `renotize.config.empty.toml`

It consists of the following keys:
- `apple_id`: The e-Mail address belonging to the Apple ID you want to use for signing applications.
- `password`: An app-specific password generated through the [management portal](https://appleid.apple.com/account/manage) of your Apple ID.
- `identity`: The identity associated with your Developer Certificate which can be found in `Keychain Access` under the category "My Certificates". It starts with `Developer ID Application:`, however it suffices to provide the 10-character code in the title of the certificate.
- `bundle`: The internal name for your app. This is typically the reverse domain notation of your website plus your application name, i.e. `com.example.mygame`.
- `altool_extra`: An optional string that will be passed on to all `altool` runs in all commands. Useful for selecting an organization when your Apple ID belongs to multiple, for example. Typically you will not have to touch this and you can leave it empty.

### Full Usage
```bash
Usage is like:
    renotize {SUBCMD} [subcommand-opts & args]
where subcommand syntaxes are as follows:

  unpack_app [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      -o=, --output-dir=  string  ""        set output_dir

  sign_app [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      --identity=         string  REQUIRED  set identity

  notarize_app [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      -b=, --bundle-id=   string  REQUIRED  set bundle_id
      -a=, --apple-id=    string  REQUIRED  set apple_id
      -p=, --password=    string  REQUIRED  set password
      --altool-extra=     string  ""        set altool_extra

  staple_app [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file

  pack_dmg [required&optional-params]
  Options:
      -i=, --input-file=   string  REQUIRED  set input_file
      -o=, --output-file=  string  REQUIRED  set output_file
      -v=, --volume-name=  string  ""        set volume_name

  sign_dmg [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      --identity=         string  REQUIRED  set identity

  notarize_dmg [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      -b=, --bundle-id=   string  REQUIRED  set bundle_id
      -a=, --apple-id=    string  REQUIRED  set apple_id
      -p=, --password=    string  REQUIRED  set password
      --altool-extra=     string  ""        set altool_extra

  staple_dmg [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file

  status [required&optional-params]
  Options:
      -u=, --uuid=      string  REQUIRED  set uuid
      -a=, --apple-id=  string  REQUIRED  set apple_id
      -p=, --password=  string  REQUIRED  set password
      --altool-extra=   string  ""        set altool_extra

  full_run [required&optional-params]
  Options:
      -i=, --input-file=  string  REQUIRED  set input_file
      -c=, --config=      string  REQUIRED  set config
```
