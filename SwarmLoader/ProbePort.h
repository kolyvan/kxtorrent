//
//  LocalprobePort.h
//  kxtorrent
//
//  Created by Kolyvan on 02.12.12.
//
//

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
