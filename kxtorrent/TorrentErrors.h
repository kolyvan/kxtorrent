//
//  TorrentErrors.h
//  kxtorrent
//
//  Created by Kolyvan on 01.11.12.
//
//

#import <Foundation/Foundation.h>

typedef enum {

    torrentErrorNone,
    torrentErrorUnexpectedFailure,
    
    torrentErrorMetaInfo,
    
    torrentErrorTrackerRequestHTTPFailure,    
    torrentErrorTrackerRequestInvalidResponse,
    
    torrentErrorFileCreateFailure,
    torrentErrorFileOpenFailure,
    torrentErrorFileReadFailure,
    torrentErrorFileWriteFailure,
    torrentErrorFileEOF,
    torrentErrorFileAbort,
    
    torrentErrorPeerHandshakeInvalidSize,
    torrentErrorPeerHandshakeInvalidProtocol,
    torrentErrorPeerHandshakeInvalidHash,
    
    torrentErrorPeerSocketFailure,
    torrentErrorPeerInvalidMessageLength,
    torrentErrorPeerUnknownMessage,
    torrentErrorPeerUnwantedBlockReceived,
    torrentErrorPeerWrongStateForPiece,
    torrentErrorPeerInvalidRequest,
    torrentErrorPeerTooManyRequest,
    torrentErrorPeerWrongStateForRequest,
    torrentErrorPeerWrongHave,
    torrentErrorPeerRecvEmptyData,
    torrentErrorPeerRecvInvalidBEP,
    torrentErrorPeerRecvInvalidPEX,
    
    torrentErrorPeerCorrupted,
    torrentErrorPeerUserDeleted,
       
} torrentError_t;

extern NSString * torrentErrorDomain;
extern NSError * torrentError (torrentError_t error, NSString *format, ...);
extern NSError * torrentErrorFromError (NSError *underlying, torrentError_t error, NSString *format, ...);
