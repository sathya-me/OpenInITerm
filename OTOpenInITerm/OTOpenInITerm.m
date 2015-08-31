//
//  OTOpenInITerm.m
//  OTOpenInITerm
//
//  Created by Sathya Narayanan p on 10/05/14.
//  Copyright (c) 2015 http://sathya.me. All rights reserved.
//


#import "OTOpenInITerm.h"

static OTOpenInITerm *sharedPlugin;
static NSArray *supportFileFormats = nil;

@interface OTOpenInITerm ()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSMenuItem *openInITermButton;

@end

@implementation OTOpenInITerm

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        
        self.bundle = plugin;
        
        supportFileFormats = @[@"xcodeproj", @"xcworkspace"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self addMenu];
}

- (void)addMenu
{
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Navigate"];
    
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSString *title = @"Reveal in iTerm";
        _openInITermButton = [[NSMenuItem alloc] initWithTitle:title
                                                           action:@selector(openProject)
                                                    keyEquivalent:@"I"];
        
        self.openInITermButton.keyEquivalentModifierMask = NSCommandKeyMask | NSAlternateKeyMask;
        
        [self.openInITermButton setTarget:self];
        [[menuItem submenu] insertItem:self.openInITermButton atIndex:3];
    }
}

- (void)openProject
{
    NSString *filePath = [self getTrueFilePath];
    
    NSString *directoryPath = [self getProjectDirectoryFromWorksapcePath:filePath];
    
    [self openProjectInITerm:directoryPath];
}

- (void)openProjectInITerm:(NSString *)projectPath
{
    if(projectPath) {

        NSString *itermPath = @"/Applications/iTerm.app";

        NSString *terminalAppPath = @"/Applications/Utilities/Terminal.app";
        
        if([[[NSFileManager alloc] init] fileExistsAtPath:itermPath]){
            terminalAppPath = itermPath;
        }
        
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:@[@"-a", terminalAppPath, projectPath]];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem == self.openInITermButton) {
        
        NSString *projectExtension = [self getProjectExtension];
        
        if ([supportFileFormats containsObject:projectExtension]) {
            
            return YES;
        } else {
            
            return NO;
        }
    }
    
    return NO;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Helpers

- (NSString *)getWorkspacePath
{
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") valueForKey:@"workspaceWindowControllers"];
    
    id workSpace;
    
    for (id controller in workspaceWindowControllers) {
        if ([[controller valueForKey:@"window"] isEqual:[NSApp keyWindow]]) {
            workSpace = [controller valueForKey:@"_workspace"];
        }
    }
    
    NSString *workspacePath = [[workSpace valueForKey:@"representingFilePath"] valueForKey:@"_pathString"];
    
    return workspacePath;
}

- (NSString *)getProjectDirectory
{
    NSString *workspacePath = [self getWorkspacePath];
    return [self getProjectExtensionFromProjectName:workspacePath];
}

- (NSString *)getProjectDirectoryFromWorksapcePath:(NSString *)workspacePath
{
    if (workspacePath) {
        
        NSMutableArray *pathComponents = [[workspacePath componentsSeparatedByString:@"/"] mutableCopy];
        
        NSString *lastComponent = [pathComponents lastObject];
        
        if (lastComponent.length == 0) { //to support file names like "folder/file.ext/"
            [pathComponents removeLastObject];
        }
        
        [pathComponents removeLastObject];
        
        NSString *workspaceFolderPath = [pathComponents componentsJoinedByString:@"/"];
        
        return workspaceFolderPath;
        
    } else {
        
        return nil;
    }
}

- (NSString *)getProjectFileName
{
    NSString *workspacePath = [self getWorkspacePath];
    return [self getProjectFileNameFromWorkSpace:workspacePath];
}

- (NSString *)getProjectFileNameFromWorkSpace:(NSString *)workspacePath
{
    if (workspacePath) {
        
        NSMutableArray *pathComponents = [[workspacePath componentsSeparatedByString:@"/"] mutableCopy];
        
        NSString *projectName = [pathComponents lastObject];
        
        return projectName;
        
    } else {
        
        return nil;
    }
}


- (NSString *)getProjectExtension
{
    NSString *projectName = [self getProjectFileName];
    return [self getProjectExtensionFromProjectName:projectName];
}

- (NSString *)getProjectExtensionFromProjectName:(NSString *)projectName
{
    if (projectName) {
        
        NSString *extension = [[projectName componentsSeparatedByString:@"."] lastObject];
        return extension;
        
    } else {
        
        return nil;
    }
}

//------------ Get True File Path ------------//

- (NSString *)getTrueFilePath
{
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") valueForKey:@"workspaceWindowControllers"];
    
    NSURL *documentURL = nil;
    
    for (id controller in workspaceWindowControllers) {
        if ([[controller valueForKey:@"window"] isEqual:[NSApp keyWindow]]) {
           
            documentURL = [[[controller valueForKey:@"editorArea"] valueForKey:@"primaryEditorDocument"] valueForKey:@"fileURL"];
        }
    }

    if (documentURL) {
        return [documentURL absoluteString];
    }
    
    return nil;
}

@end
