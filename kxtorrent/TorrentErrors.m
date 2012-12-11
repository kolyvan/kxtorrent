//
//  TorrentErrors.m
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//
//

#import "TorrentErrors.h"
#import "KxUtils.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_ERROR;

NSString * torrentErrorDomain = @"ru.kolyvan.torrent";

static NSString * torrentErrorStringForCode(torrentError_t error)
{
    switch (error) {
        case torrentErrorUnexpectedFailure: return @"Unexpected failure";
        case torrentErrorMetaInfo: return @"Invalid metainfo";
        case torrentErrorTrackerRequestHTTPFailure: return @"HTTP request failure";
        case torrentErrorTrackerRequestInvalidResponse: return @"Invalid tracker response";
        case torrentErrorFileCreateFailure: return @"Unable create a file";
        case torrentErrorFileOpenFailure: return @"Unable open a file";
        case torrentErrorFileReadFailure: return @"Unable read a file";
        case torrentErrorFileWriteFailure: return @"Unable write a file";
        case torrentErrorFileEOF: return @"End of file";
        case torrentErrorFileAbort: return @"Abort file IO";
        case torrentErrorPeerHandshakeInvalidSize: return @"Handshake has an invalid size";
        case torrentErrorPeerHandshakeInvalidProtocol: return @"Handshake has an invalid protocol";
        case torrentErrorPeerHandshakeInvalidHash: return @"Handshake has an invalid hash";
        case torrentErrorPeerSocketFailure: return @"Peer socket failure";
        case torrentErrorPeerInvalidMessageLength: return @"Peer sent a message with invalid length";
        case torrentErrorPeerUnknownMessage: return @"Peer sent an unknown message";
        case torrentErrorPeerUnwantedBlockReceived: return @"Peer sent an unwanted block";
        case torrentErrorPeerWrongStateForPiece: return @"Peer sent piece in wrong state";
        case torrentErrorPeerInvalidRequest: return @"Peer sent invalid request";
        case torrentErrorPeerTooManyRequest: return @"Peer sent too many requests";
        case torrentErrorPeerWrongStateForRequest: return @"Peer sent request in wrong state";
        case torrentErrorPeerWrongHave: return @"Peer sent wrong have";
        case torrentErrorPeerRecvEmptyData: return @"Peer sent empty data";
        case torrentErrorPeerRecvInvalidBEP: return @"Peer sent invalid BEP";
        case torrentErrorPeerRecvInvalidPEX:  return @"Peer sent invalid PEX";
        case torrentErrorPeerCorrupted: return @"Peer is corrupted";
        case torrentErrorPeerUserDeleted: return @"Peer closed by user";
            
        default:
            return @"Unknown failure";
    }    
}

NSError * torrentError (torrentError_t error, NSString *format, ...)
{
    NSDictionary *userInfo = nil;
    NSString *reason = nil;
    
    if (format) {
    
        va_list args;
        va_start(args, format);
        reason = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    
    if (reason) {
        
        userInfo = @{
            NSLocalizedDescriptionKey : torrentErrorStringForCode(error),
            NSLocalizedFailureReasonErrorKey : reason
        };
        
    } else {
        
        userInfo = @{ NSLocalizedDescriptionKey : torrentErrorStringForCode(error) };
    }
    
    DDLogCVerbose(@"torrent error #%d %@", error, reason);
    
    return [NSError errorWithDomain:(NSString *)torrentErrorDomain
                               code:error
                           userInfo:userInfo];
}

NSError * torrentErrorFromError (NSError *underlying, torrentError_t error, NSString *format, ...)
{
    NSDictionary *userInfo = nil;    
    NSString *reason = nil;
    
    if (format) {
        
        va_list args;
        va_start(args, format);
        reason = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    
    if (reason) {
        
        userInfo = @{
            NSLocalizedDescriptionKey : torrentErrorStringForCode(error),
            NSLocalizedFailureReasonErrorKey : reason,
            NSUnderlyingErrorKey : underlying
        };
        
    } else {
        
        userInfo = @{
            NSLocalizedDescriptionKey : torrentErrorStringForCode(error),
            NSUnderlyingErrorKey : underlying
        };
    }
    
     DDLogCVerbose(@"torrent error #%d %@, underlying: %@",
                error, reason, KxUtils.completeErrorMessage(underlying));
    
    return [NSError errorWithDomain:(NSString *)torrentErrorDomain
                               code:error
                           userInfo:userInfo];
}