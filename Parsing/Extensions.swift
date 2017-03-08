//
//  Extensions.swift
//  Netopsy
//
//  Created by Dave Weston on 2/16/17.
//  Copyright © 2017 Binocracy. All rights reserved.
//

import Foundation

extension TLS {
    public struct Extension {
        public struct ExtensionType {
            public enum RawExtensionType {
                case unassigned
                case server_name
                case max_fragment_length
                case client_certificate_url
                case trusted_ca_keys
                case truncated_hmac
                case status_request
                case user_mapping
                case client_authz
                case server_authz
                case cert_type
                case supported_groups
                case ec_point_formats
                case srp
                case signature_algorithms
                case use_srtp
                case heartbeat
                case application_layer_protocol_negotiation
                case status_request_v2
                case signed_certificate_timestamp
                case client_certificate_type
                case server_certificate_type
                case padding
                case encrypt_then_mac
                case extended_master_secret
                case token_binding
                case cached_info
                case SessionTicketTLS
                case renegotiation_info
            }

            private static let map: [UInt16: RawExtensionType] = [
                0: .server_name,
                1: .max_fragment_length,
                2: .client_certificate_url,
                3: .trusted_ca_keys,
                4: .truncated_hmac,
                5: .status_request,
                6: .user_mapping,
                7: .client_authz,
                8: .server_authz,
                9: .cert_type,
                10: .supported_groups,
                11: .ec_point_formats,
                12: .srp,
                13: .signature_algorithms,
                14: .use_srtp,
                15: .heartbeat,
                16: .application_layer_protocol_negotiation,
                17: .status_request_v2,
                18: .signed_certificate_timestamp,
                19: .client_certificate_type,
                20: .server_certificate_type,
                21: .padding,
                22: .encrypt_then_mac,
                23: .extended_master_secret,
                24: .token_binding,
                25: .cached_info,
                35: .SessionTicketTLS,
                65281: .renegotiation_info,
                ]

            public var code: UInt16
            public var type: RawExtensionType

            public init(rawValue: UInt16) {
                self.code = rawValue
                self.type = ExtensionType.map[rawValue] ?? .unassigned
            }
        }

        public struct ServerName {
            public struct NameType {
                private static let map: [UInt8: RawNameType] = [
                    0: .host_name,
                ]

                public enum RawNameType {
                    case unassigned
                    case host_name
                }

                var code: UInt8
                var type: RawNameType

                public init(rawValue: UInt8) {
                    self.code = rawValue
                    self.type = NameType.map[rawValue] ?? .unassigned
                }
            }
        }

        public struct MaximumFragmentLength {
            private static let map: [UInt8: RawMaxFragmentLength] = [
                1: .max512,
                2: .max1024,
                3: .max2048,
                4: .max4096,
            ]

            enum RawMaxFragmentLength {
                case unassigned
                case max512
                case max1024
                case max2048
                case max4096
            }

            var code: UInt8
            var type: RawMaxFragmentLength

            public init(rawValue: UInt8) {
                self.code = rawValue
                self.type = MaximumFragmentLength.map[rawValue] ?? .unassigned
            }
        }

        public struct ClientCertificateURLs {
            public struct CertChainType {
                private static let map: [UInt8: RawCertChainType] = [
                    0: .individual_certs,
                    1: .pkipath,
                ]

                enum RawCertChainType {
                    case unassigned
                    case individual_certs
                    case pkipath
                }

                var code: UInt8
                var type: RawCertChainType

                public init(rawValue: UInt8) {
                    self.code = rawValue
                    self.type = CertChainType.map[rawValue] ?? .unassigned
                }
            }

            public struct URLAndHash {
                var url: [UInt8]
                var padding: UInt8
                var sha1Hash: [UInt8] // 20 bytes
            }

            public struct CertifcateURL {
                var type: CertChainType
                var urlAndHashList: [URLAndHash]
            }

        }

        public struct TrustedCAIndication {
            public struct IdentifierType {
                public enum RawIdentifierType {
                    case unassigned
                    case pre_agreed
                    case key_sha1_hash
                    case x509_name
                    case cert_sha1_hash
                }

                private static let map: [UInt8: RawIdentifierType] = [
                    0: .pre_agreed,
                    1: .key_sha1_hash,
                    2: .x509_name,
                    3: .cert_sha1_hash,
                ]

                var code: UInt8
                var type: RawIdentifierType

                init(rawValue: UInt8) {
                    self.code = rawValue
                    self.type = IdentifierType.map[rawValue] ?? .unassigned
                }
            }

            struct TrustedAuthority {
                var identifierType: IdentifierType
                var identifier: [UInt8]?
            }

            struct TrustedAuthorities {
                var trustedAuthoritiesList: [TrustedAuthority]
            }
        }

        struct CertificateStatusRequests {
            struct CertificateStatusType {
                enum RawCertificateStatusType {
                    case unassigned
                    case ocsp
                }

                private static let map: [UInt8: RawCertificateStatusType] = [
                    0: .ocsp
                ]

                var code: UInt8
                var type: RawCertificateStatusType

                init(rawValue: UInt8) {
                    self.code = rawValue
                    self.type = CertificateStatusType.map[rawValue] ?? .unassigned
                }
            }

            struct OCSPStatusRequest {
                var responderIdList: [UInt8]
                var requestExtensions: [UInt8]
            }

            struct CertificateStatusRequest {
                var type: CertificateStatusType
                var request: OCSPStatusRequest
            }
        }

        struct SignatureAlgorithms {
            enum HashAlgorithm: UInt8 {
                case none = 0
                case md5 = 1
                case sha1 = 2
                case sha224 = 3
                case sha256 = 4
                case sha384 = 5
                case sha512 = 6
            }

            enum SignatureAlgorithm: UInt8 {
                case anonymous = 0
                case rsa = 1
                case dsa = 2
                case ecdsa = 3
            }

            struct SignatureAndHashAlgorithm {
                var hash: HashAlgorithm
                var signature: SignatureAlgorithm
            }
        }

        struct ECPointFormat {
            enum RawECPointFormat {
                case unknown
                case uncompressed
                case ansiX962_compressed_prime
                case ansiX962_compressed_char2
                case reserved
            }

            static private let map: [UInt8: RawECPointFormat] = [
                0: .uncompressed,
                1: .ansiX962_compressed_prime,
                2: .ansiX962_compressed_char2,
            ]

            var code: UInt8
            var type: RawECPointFormat
            init(rawValue: UInt8) {
                code = rawValue
                if rawValue >= 248 && rawValue <= 255 {
                    type = .reserved
                } else {
                    type = ECPointFormat.map[rawValue] ?? .unknown
                }
            }
        }

        struct NamedCurve {
            enum RawNamedCurve {
                case unassigned
                case sect163k1
                case sect163r1
                case sect163r2
                case sect193r1
                case sect193r2
                case sect233k1
                case sect233r1
                case sect239k1
                case sect283k1
                case sect283r1
                case sect409k1
                case sect409r1
                case sect571k1
                case sect571r1
                case secp160k1
                case secp160r1
                case secp160r2
                case secp192k1
                case secp192r1
                case secp224k1
                case secp224r1
                case secp256k1
                case secp256r1
                case secp384r1
                case secp521r1
                case ffdhe2048
                case ffdhe3072
                case ffdhe4096
                case ffdhe6144
                case ffdhe8192
                case reserved
                case arbitrary_explicit_prime_curves
                case arbitrary_explicit_char2_curves
            }

            private static let map: [UInt16: RawNamedCurve] = [
                1: .sect163k1,
                2: .sect163r1,
                3: .sect163r2,
                4: .sect193r1,
                5: .sect193r2,
                6: .sect233k1,
                7: .sect233r1,
                8: .sect239k1,
                9: .sect283k1,
                10: .sect283r1,
                11: .sect409k1,
                12: .sect409r1,
                13: .sect571k1,
                14: .sect571r1,
                15: .secp160k1,
                16: .secp160r1,
                17: .secp160r2,
                18: .secp192k1,
                19: .secp192r1,
                20: .secp224k1,
                21: .secp224r1,
                22: .secp256k1,
                23: .secp256r1,
                24: .secp384r1,
                25: .secp521r1,
                256: .ffdhe2048,
                257: .ffdhe3072,
                258: .ffdhe4096,
                259: .ffdhe6144,
                260: .ffdhe8192,
                0xff01: .arbitrary_explicit_prime_curves,
                0xff02: .arbitrary_explicit_char2_curves
            ]

            var code: UInt16
            var type: RawNamedCurve

            init(rawValue: UInt16) {
                self.code = rawValue
                if rawValue >= 0xfe00 && rawValue <= 0xfeff {
                    self.type = .reserved
                }
                else {
                    self.type = NamedCurve.map[rawValue] ?? .unassigned
                }
            }
        }
        
        public var type: ExtensionType
        public var extensionData: [UInt8]
    }
}

