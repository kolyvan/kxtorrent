//
//  LocalprobePort.h
//  kxtorrent
//
//  Created by Kolyvan on 02.12.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxtorrent
//  this file is part of KxTorrent
//  KxTorrent is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>


typedef enum {

    ProbePortResultSocketError,
    ProbePortResultReachable,
    ProbePortResultNotReachable,
    ProbePortResultInvalidResponse,
    
} ProbePortResult;

typedef void(^ProbePortBlock)(NSUInteger port, ProbePortResult result);

@interface ProbePort : NSObject

+ (id) probePort: (NSUInteger) port
        complete: (ProbePortBlock) block;

- (void) close;

@end
