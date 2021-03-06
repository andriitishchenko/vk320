//
//  RSDownloadItem.m
//  VK320
//
//  Created by Roman Silin on 13.07.14.
//  Copyright (c) 2014 Roman Silin. All rights reserved.
//

#import "RSDownloadItem.h"
#import "RSAppDelegate.h"

@implementation RSDownloadItem

+ (RSDownloadItem *)initWithAudioItem:(RSAudioItem *)audioItem {
    
    RSDownloadItem *downloadItem = [[RSDownloadItem alloc] init];
    
    NSString *filename = [NSString stringWithFormat:@"%@ - %@", [audioItem.artist clearBadPathSymbols], [audioItem.title clearBadPathSymbols]];
    if ([filename length] > 251) {
        filename = [filename substringWithRange:NSMakeRange(0, 251)];
    }

    NSURL *fileURL = [[AppDelegate downloadsDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", filename]];
    downloadItem.path = fileURL;
    downloadItem.duration = audioItem.duration;
    downloadItem.kbps = audioItem.kbps;
    downloadItem.size = audioItem.size;
    downloadItem.sizeDownloaded = 0;
    downloadItem.url = audioItem.url;
    downloadItem.status = RSDownloadAddedJustNow;
    downloadItem.operation = nil;
    downloadItem.audioItem = audioItem;
    downloadItem.vkID = audioItem.vkID;
    
    return downloadItem;
    
}

- (void)start {
    
    if ([self.delegate readyForStartDownload]) {
        
        if (![self.delegate internetAvailable]) {
            [[self.delegate alertView] showAlert:NSLocalizedString(@"ALERT_CONNECTION_OFF", nil) withcolor:[NSColor pxColorWithHexValue:COLOR_ALERT_RED] autoHide:YES];
            self.status = RSDownloadReady;
            return;
        }

        self.status = RSDownloadAddedJustNow;
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.url]];
        __weak typeof(self)weakSelf = self;
        
        AFHTTPRequestOperationManager *manager = [self.delegate networkManager];
        AFHTTPRequestOperation *operation = [manager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            __strong typeof(weakSelf)blocksafeSelf = weakSelf;
            blocksafeSelf.status = RSDownloadCompleted;
            blocksafeSelf.operation = nil;
            [blocksafeSelf.delegate updateDownloadItem:blocksafeSelf];
            [[AppDelegate downloadsDirectory] stopAccessingSecurityScopedResource];
            [blocksafeSelf.delegate downloadCompleted];

        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            
            if (error.code == -1005) {
                [[self.delegate alertView] showAlert:NSLocalizedString(@"ALERT_CONNECTION_OFF", nil) withcolor:[NSColor pxColorWithHexValue:COLOR_ALERT_RED] autoHide:YES];

                [self setStatus:RSDownloadReady];
                [self setSizeDownloaded:0];
                [self.delegate updateDownloadItem:self];
                
            } else if (error.code == 2) {
                
                [self.delegate.alertView showAlert:NSLocalizedString(@"ALERT_DOWNLOADS_PATH", nil) withcolor:[NSColor pxColorWithHexValue:COLOR_ALERT_RED] autoHide:YES];
                [self setStatus:RSDownloadReady];
                [self setSizeDownloaded:0];
                [self.delegate updateDownloadItem:self];                
                
            } else {
                
                [self.delegate showError:error withType:RSErrorNetwork];
                
            }
            
        }];
        
        [[AppDelegate downloadsDirectory] startAccessingSecurityScopedResource];
        [AFHTTPRequestOperationManager manager].responseSerializer.acceptableContentTypes = [[AFHTTPRequestOperationManager manager].responseSerializer.acceptableContentTypes setByAddingObject:@"audio/mpeg"];
        [operation setOutputStream:[NSOutputStream outputStreamWithURL:self.path append:NO]];
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            __strong typeof(weakSelf)blocksafeSelf = weakSelf;
            if (blocksafeSelf.status == RSDownloadAddedJustNow) {
                blocksafeSelf.status = RSDownloadInProgress;
                [self.delegate updateDownloadsButtons];
            }
            blocksafeSelf.sizeDownloaded = totalBytesRead;
            [blocksafeSelf.delegate updateDownloadItem:blocksafeSelf];
        }];
        [operation start];
        [self setOperation:operation];
        
    } else {
        
        self.status = RSDownloadReady;
        
    }
    
}

- (void)pause {
    
    if (self.operation && [self.operation isExecuting]) {
        [self.operation pause];
        [self setStatus:RSDownloadPause];
        [self.delegate updateDownloadItem:self];
    }
    
}

- (void)resume {

    if (self.operation && [self.operation isPaused]) {
        
        if (![self.delegate internetAvailable]) {
            [self.delegate showError:[NSError errorWithDomain:@"" code:-1009 userInfo:nil] withType:RSErrorNetwork];
            return;
        }

        [self.operation resume];
        [self setStatus:RSDownloadInProgress];
        [self.delegate updateDownloadItem:self];        
    } else {
        NSLog(@"Resume download Error");
    }

}

- (void)resetWithNoFile {
    self.status = RSDownloadFileNotFound;
    self.sizeDownloaded = 0;
    [self.delegate updateDownloadItem:self];
    [self.delegate updateAudioItem:self.audioItem];
}

- (void)removeFile {
    
    NSError *error;
    [[AppDelegate downloadsDirectory] startAccessingSecurityScopedResource];
    if ([[NSFileManager defaultManager] isDeletableFileAtPath:[self.path path]]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtURL:self.path error:&error];
        if (!success) {
            NSLog(@"Error removing file at path: %@", error.localizedDescription);
        }
    }
    [[AppDelegate downloadsDirectory] stopAccessingSecurityScopedResource];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    
	[encoder encodeObject:self.path forKey:@"path"];
	[encoder encodeInteger:self.duration forKey:@"duration"];
	[encoder encodeInteger:self.size forKey:@"size"];
   	[encoder encodeInteger:self.kbps forKey:@"kbps"];
	[encoder encodeObject:self.vkID forKey:@"vkID"];
    [encoder encodeObject:self.url forKey:@"url"];
	[encoder encodeInteger:self.status forKey:@"status"];
	[encoder encodeInteger:self.sizeDownloaded forKey:@"sizeDownloaded"];
    
}

- (id)initWithCoder:(NSCoder *)decoder {
    
	self = [super init];
	if( self != nil ) {
        self.path = [decoder decodeObjectForKey:@"path"];
        self.duration = [decoder decodeIntegerForKey:@"duration"];
        self.size = [decoder decodeIntegerForKey:@"size"];
        self.kbps = [decoder decodeIntegerForKey:@"kbps"];
        self.url = [decoder decodeObjectForKey:@"url"];
        self.vkID = [decoder decodeObjectForKey:@"vkID"];
        self.status = [decoder decodeIntegerForKey:@"status"];
        self.sizeDownloaded = [decoder decodeIntegerForKey:@"sizeDownloaded"];
        self.operation = nil;
	}
	return self;
}

@end
