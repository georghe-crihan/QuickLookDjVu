# This section intends to list the important steps for creating a thumbnail extension.
qlgenerator has been deprecated and removed in platforms we support. App extensions are the way
forward. But there's little guidance on how to do it outside Xcode.

> Support for deprecated Quick Look Generator plugins is being removed. To provide previews and thumbnails for your custom file types,
> migrate to Quick Look Preview Extension and Thumbnail Extension API. (116791365)

The process of thumbnail generation goes something like this:
1. If an app is launched, or is registered with *lsregister*, its plugins also get registered.
2. When a file thumbnail in Finder or QuickLook is requested, the system looks for a plugin
that supports the file type UTI.
3. The plugin is launched in a sand-boxed environment and should call the handler with a reply.

# Plugin Info.plist
The *Info.plist* file should be properly configured with supported content type.

# Codesigning
The plugin should be codesigned with entitlements at least for sandbox  and read-only/
read-write (for access to the given file). It's needed to even run the plugin locally.
`com.apple.security.get-task-allow` entitlement is required for debugging.

# Registering the plugin
The plugin should be registered with *lsregister*. Either by calling `lsregister` or by launching
the parent app.
```
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
-dump | grep djvu-thumbnailer
``` 
 
# Debugging
Since read-only entitlement is there, creating files to log is not possible. So `NSLog` and
viewing it in `Console.app` (after triggering a thumbnail) is the way to go. Interesting processes
are: `qlmanage`, `quicklookd`, `kernel`, `djvu-thumbnailer`, `secinitd`,
`com.apple.quicklook.ThumbnailsAgent`.

LLDB/ Xcode etc., debuggers can be used to get extra logs than CLI invocation but breakpoints
still are a pain point. `/usr/bin/qlmanage` is the target executable. Other args to *qlmanage*
follow. 
```
lldb qlmanage --  -t -x a.djvu
```

# Troubleshooting
- The appex shouldn't have any quarantine flag.
```
   xattr -rl bin/Djvu.app/Contents/Plugins/djvu-thumbnailer.appex
```
- Is it registered with *lsregister* and there isn't a conflict with another plugin taking
  precedence?
```
lsregister -dump | grep djvu-thumbnailer.appex
```
- For `RBSLaunchRequest` error: is the executable flag set?
```
chmod u+x bin/Djvu.app/Contents/PlugIns/djvu-thumbnailer.appex/Contents/MacOS/djvu-thumbnailer
```
- Is it codesigned and sandboxed?
Check:
```
codesign --display --verbose --entitlements - --xml \
  bin/Djvu.app/Contents/Plugins/djvu-thumbnailer.appex
```
Sign:
```
 codesign --deep --force --sign - \
  --entitlements ../djvu/release/darwin/thumbnailer_entitlements.plist --timestamp=none \
  bin/Djvu.app/Contents/Plugins/djvu-thumbnailer.appex
```
- Sometimes *djvu-thumbnailer* running in background can be killed.
- ```qlmanage -r && killall Finder```
- The code cannot attempt to do anything outside sandbox like writing to djvu.

# Triggering a thumbnail
- ```qlmanage -t -x /path/to/file.djvu```

# External resources
https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/Quicklook_Programming_Guide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40005020-CH1-SW1
 
