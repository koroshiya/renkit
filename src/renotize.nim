import std/os
import std/json
import std/base64
import std/osproc
import std/strutils
import std/sequtils
import std/browsers
import std/strformat

import plists
import zippy/ziparchives
when isMainModule: import cligen

# rcodesign requires Visual C++ 2015 Redistributable Update 3 RC on Windows:
# https://www.microsoft.com/en-us/download/details.aspx?id=52685

when defined(mingw):
  const rcodesignBin = staticRead("../rcodesign.exe")
  let rcodesignPath = getTempDir() / "rcodesign.exe"
else:
  const rcodesignBin = staticRead("../rcodesign")
  let rcodesignPath = getTempDir() / "rcodesign"

var eCode = 0
try:
  eCode = execCmdEx(&"{rcodesignPath} -V").exitCode
except CatchableError:
  eCode = 1

if eCode != 0:
  echo &"Writing rcodesign to {rcodesignPath}"
  writeFile(rcodesignPath, rcodesignBin)
  setFilePermissions(rcodesignPath, {fpUserRead, fpUserWrite, fpUserExec})

type KeyboardInterrupt = object of CatchableError

proc handler() {.noconv.} =
  raise newException(KeyboardInterrupt, "Keyboard Interrupt")

setControlCHook(handler)

proc provision*() =
  ## Utility method to provision required information for notarization using a step-by-step process.
  # generate private key for code signing request
  discard execCmd("openssl genrsa -out private-key.pem 2048")

  # generate CSR
  discard execCmd(&"{rcodesignPath} generate-certificate-signing-request --pem-source private-key.pem --csr-pem-path csr.pem")

  # upload CSR to apple
  echo "This next step should be completed in the browser."
  echo "Press 'Enter' to open the browser and continue."
  discard readLine(stdin)
  openDefaultBrowser("https://developer.apple.com/account/resources/certificates/add")

  # print step by step instructions
  echo "1. Select 'Developer ID Application' as the certificate type"
  echo "2. Click 'Continue'"
  echo "3. Select the G2 Sub-CA (Xcode 11.4.1 or later) Profile Type"
  echo "4. Select 'csr.pem' using the file picker"
  echo "5. Click 'Continue'"
  echo "6. Click the 'Download' button to download your certificate"
  echo "7. Save the certificate next to the private-key.pem and csr.pem files"

  echo "Press 'Enter' when you have saved the certificate"
  discard readLine(stdin)

  let certFiles = walkFiles(getCurrentDir() / "*.cer").toSeq()
  if certFiles.len == 0:
    echo "No .cer file found in current directory"
    quit(1)

  echo "This next step should be completed in the browser."
  echo "Press 'Enter' to open the browser and continue."
  discard readLine(stdin)
  openDefaultBrowser("https://appstoreconnect.apple.com/access/users")

  echo "1. Click on 'Keys'"
  echo "2. If this is your first time, click on 'Request Access' and wait until it is granted"
  echo "3. Click on 'Generate API Key'"
  echo "4. Enter a name for the key"
  echo "5. For Access, select 'Developer'"
  echo "6. Click on 'Generate'"
  echo "7. Copy the Issuer ID and enter it here: ('Enter' to confirm)"
  let issuerId = readLine(stdin).strip()
  if issuerId.len == 0:
    echo "Issuer ID cannot be empty"
    quit(1)
  echo "8. Copy the Key ID and enter it here: ('Enter' to confirm)"
  let keyId = readLine(stdin).strip()
  if keyId.len == 0:
    echo "Key ID cannot be empty"
    quit(1)
  echo "9. Next to the entry of the newly-created key in the list, click on 'Download API Key'"
  echo "10. In the following pop-up, Click on 'Download'"
  echo "11. Save the downloaded .p8 file next to the private-key.pem and csr.pem files"

  echo "Press 'Enter' when you have saved the certificate"
  discard readLine(stdin)

  # find the first file ending in .p8
  let p8Files = walkFiles(getCurrentDir() / "*.p8").toSeq()
  if p8Files.len == 0:
    echo "No .p8 file found in current directory"
    quit(1)
  discard execCmdEx(&"{rcodesignPath} encode-app-store-connect-api-key -o app-store-key.json {issuerId} {keyId} {p8Files[0]}")

  echo "Success!"
  echo "You can now sign your app using these two files:"
  echo "  - private-key.pem"
  echo &"  - {certFiles[0]}"
  echo "You can also use this file to notarize your app:"
  echo "  - app-store-key.json"

  let jsonData = %*{
    "privateKey": readFile("private-key.pem").encode(),
    "certificate": readFile(certFiles[0]).encode(),
    "appStoreKey": readFile("app-store-key.json").encode()
  }
  writeFile("renotize.json", jsonData.pretty())

  echo "You can also use this single file to notarize your app:"
  echo "  - renotize.json"

  echo "You can supply the contents of this file via the environment variable RENOTIZE_JSON"
  echo "so that you don't have to supply the private key and certificate individually every time."

proc unpackApp*(inputFile, bundleIdentifier: string, outputDir = "") =
  ## Unpacks the given ZIP file to the target directory.
  var targetDir = outputDir
  if targetDir != "" and dirExists(targetDir):
    removeDir(targetDir)
  if targetDir == "":
    targetDir = inputFile
    removeSuffix(targetDir, ".zip")

  extractAll(inputFile, targetDir)

  let extractedFile = walkDirs(joinPath(targetDir, "*.app")).toSeq()[0]
  let newTargetDir = joinPath(splitPath(targetDir)[0], splitPath(extractedFile)[1])
  moveFile(extractedFile, newTargetDir)
  removeDir(targetDir)

  let plistPath = joinPath(newTargetDir, "Contents", "Info.plist")

  let p = loadPlist(plistPath)
  p["CFBundleIdentifier"] = %bundleIdentifier
  writePlist(p, plistPath)

proc signApp*(inputFile: string, keyFile: string, certFile: string) =
  ## Signs a .app bundle with the given Developer Identity.
  let entitlements = """<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/></dict></plist>"""

  writeFile("entitlements.plist", entitlements)

  discard execCmd(&"{rcodesignPath} sign --code-signature-flags runtime -e entitlements.plist --pem-source {keyFile} --der-source {certFile} {inputFile}")

  removeFile("entitlements.plist")

proc notarizeApp*(inputFile: string, appStoreKeyFile: string): string =
  ## Notarizes a .app bundle with the given Developer Account and bundle ID.
  discard execCmd(&"{rcodesignPath} notary-submit --api-key-path {appStoreKeyFile} --staple {inputFile}")

proc packDmg*(
  inputFile: string,
  outputFile: string,
  volumeName = "",
) =
  ## Packages a .app bundle into a .dmg file.
  var vName = volumeName
  if volumeName == "":
    vName = changeFileExt(lastPathPart(inputFile), "")
  let cmd = &"hdiutil create -fs HFS+ -format UDBZ -ov -volname {vName} -srcfolder {inputFile} {outputFile}"
  discard execShellCmd(cmd)

proc signDmg*(inputFile: string, keyFile: string, certFile: string) =
  ## Signs a .dmg file with the given Developer Identity.
  discard execCmd(&"{rcodesignPath} sign --pem-source {keyFile} --der-source {certFile} {inputFile}")

proc notarizeDmg*(inputFile: string, appStoreKeyFile: string): string =
  ## Notarizes a .dmg file with the given Developer Account and bundle ID.
  discard execCmd(&"{rcodesignPath} notary-submit --api-key-path {appStoreKeyFile} --staple {inputFile}")

proc status*(uuid: string, appStoreKeyFile: string): string =
  ## Checks the status of a notarization operation given its UUID.
  let data = parseJson(execProcess(&"{rcodesignPath} notary-log --api-key-path {appStoreKeyFile} {uuid}"))

  var status = "not started"
  if "notarization-info" in data:
    status = data["notarization-info"]["Status"].getStr()

  return status

proc fullRun*(inputFile, bundleIdentifier, keyFile, certFile, appStoreKeyFile: string) =
  # Programmatic interface for the full run operation to allow
  # dynamically passing in configuration data from memory at runtime.
  echo "Unpacking app"
  unpackApp(inputFile, bundleIdentifier)

  let appFile = walkDirs(joinPath(splitPath(inputFile)[0], "*.app")).toSeq()[0]

  echo "Signing app"
  signApp(appFile, keyFile, certFile)

  echo "Notarizing app"
  echo notarizeApp(appFile, appStoreKeyFile)

  let (dir, name, _) = splitFile(appFile)
  let dmgFile = &"{joinPath(dir, name)}.dmg"

  echo "Packing DMG"
  packDmg(appFile, dmgFile)

  echo "Signing DMG"
  signDmg(dmgFile, keyFile, certFile)

  echo "Notarizing DMG"
  echo notarizeDmg(dmgFile, appStoreKeyFile)

  echo "Done"

proc fullRunCli*(inputFile: string, bundleIdentifier = "", keyFile = "", certFile = "", appStoreKeyFile = "", jsonBundleFile = "") =
  ## Fully notarize a given .app bundle, creating a signed
  ## and notarized artifact for distribution.
  var
    keyFileInt: string
    certFileInt: string
    renotizeJsonRaw: string
    appStoreKeyFileInt: string
    bundleIdentifierInt: string

  if jsonBundleFile == "":
    renotizeJsonRaw = getEnv("RENOTIZE_JSON")
  else:
    renotizeJsonRaw = readFile(jsonBundleFile)

  if renotizeJsonRaw != "":
    let renotizeJson = renotizeJsonRaw.parseJson()
    keyFileInt = renotizeJson["privateKey"].getStr().decode()

    let tmpKeyFile = getTempDir() / "private-key.pem"
    writeFile(tmpKeyFile, keyFileInt)
    keyFileInt = tmpKeyFile

    certFileInt = renotizeJson["certificate"].getStr().decode()

    let tmpCertFile = getTempDir() / "certificate.cer"
    writeFile(tmpCertFile, certFileInt)
    certFileInt = tmpCertFile

    appStoreKeyFileInt = renotizeJson["appStoreKey"].getStr().decode()

    let tmpAppStoreKeyFile = getTempDir() / "app-store-key.json"
    writeFile(tmpAppStoreKeyFile, appStoreKeyFileInt)
    appStoreKeyFileInt = tmpAppStoreKeyFile
  else:
    if keyFile == "":
      keyFileInt = getEnv("RN_KEY_FILE")
    else:
      keyFileInt = keyFile
    if certFile == "":
      certFileInt = getEnv("RN_CERT_FILE")
    else:
      certFileInt = certFile
    if appStoreKeyFile == "":
      appStoreKeyFileInt = getEnv("RN_APP_STORE_KEY_FILE")
    else:
      appStoreKeyFileInt = appStoreKeyFile

  if bundleIdentifier == "":
    bundleIdentifierInt = getEnv("RN_BUNDLE_IDENTIFIER")
  else:
    bundleIdentifierInt = bundleIdentifier

  if keyFileInt == "" or certFileInt == "" or appStoreKeyFileInt == "" or bundleIdentifierInt == "":
    echo "No configuration data was found via command line arguments or environment."
    quit(1)

  fullRun(inputFile, bundleIdentifier, keyFileInt, certFileInt, appStoreKeyFileInt)

when isMainModule:
  dispatchMulti(
    [provision],
    [unpackApp, cmdName="unpack-app", help = {
        "inputFile": "The path to the ZIP file containing the .app bundle.",
        "outputDir": "The directory to extract the .app bundle to.",
    }],
    [signApp, cmdName="sign-app", help = {
        "inputFile": "The path to the .app bundle.",
        "keyFile": "The private key generated via the 'provision' command.",
        "certFile": "The certificate file obtained via the 'provision' command.",
    }],
    [notarizeApp, cmdName="notarize-app", help = {
        "inputFile": "The path to the .app bundle.",
        "appStoreKeyFile": "The app-store-key.json file obtained via the 'provision' command.",
    }],
    [packDmg, cmdName="pack-dmg", help = {
        "inputFile": "The path to the .app bundle.",
        "outputFile": "The name of the DMG file to write to.",
        "volumeName": "The name to use for the DMG volume. By default the base name of the input file."
    }],
    [signDmg, cmdName="sign-dmg", help = {
        "inputFile": "The path to the .dmg file.",
        "keyFile": "The private key generated via the 'provision' command.",
        "certFile": "The certificate file obtained via the 'provision' command.",
    }],
    [notarizeDmg, cmdName="notarize-dmg", help = {
        "inputFile": "The path to the .dmg file.",
        "appStoreKeyFile": "The app-store-key.json file obtained via the 'provision' command.",
    }],
    [status, help = {
        "uuid": "The UUID of the notarization operation.",
        "appStoreKeyFile": "The app-store-key.json file obtained via the 'provision' command.",
    }],
    [fullRunCli, cmdName = "full-run", help = {
        "inputFile": "The path to the the ZIP file containing the .app bundle.",
        "bundleIdentifier": "The internal identifier of the .app bundle.",
        "keyFile": "The private key generated via the 'provision' command.",
        "certFile": "The certificate file obtained via the 'provision' command.",
        "appStoreKeyFile": "The app-store-key.json file obtained via the 'provision' command.",
        "jsonBundleFile": "The renotize.json file obtained via the 'provision' command. If this is set, the other arguments are ignored.",
    }],
  )
