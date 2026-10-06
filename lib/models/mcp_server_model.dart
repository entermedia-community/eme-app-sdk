import 'package:flutter/material.dart';

/// Transport type used to connect to remote MCP Server
enum McpTransportType {
  sse,
  httpPost,
  websocket;

  String get displayName {
    switch (this) {
      case McpTransportType.sse:
        return 'Server-Sent Events (SSE)';
      case McpTransportType.httpPost:
        return 'HTTP JSON-RPC';
      case McpTransportType.websocket:
        return 'WebSocket (WS/WSS)';
    }
  }

  static McpTransportType fromString(String? val) {
    if (val == null) return McpTransportType.sse;
    switch (val.toLowerCase().trim()) {
      case 'httppost':
      case 'http':
      case 'jsonrpc':
        return McpTransportType.httpPost;
      case 'websocket':
      case 'ws':
      case 'wss':
        return McpTransportType.websocket;
      case 'sse':
      default:
        return McpTransportType.sse;
    }
  }
}

/// Connection status of the remote MCP Server
enum McpServerStatus {
  disconnected,
  connecting,
  connected,
  error;

  bool get isConnected => this == McpServerStatus.connected;
  bool get isConnecting => this == McpServerStatus.connecting;
  bool get isError => this == McpServerStatus.error;
}

/// Definition of an MCP Tool advertised by the remote server
class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const McpToolDefinition({
    required this.name,
    this.description = '',
    this.inputSchema = const {},
  });

  factory McpToolDefinition.fromJson(Map<String, dynamic> json) {
    return McpToolDefinition(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      inputSchema: json['inputSchema'] is Map<String, dynamic>
          ? json['inputSchema'] as Map<String, dynamic>
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }

  /// Extracts properties map from json schema
  Map<String, dynamic> get properties {
    final props = inputSchema['properties'];
    if (props is Map<String, dynamic>) {
      return props;
    }
    return {};
  }

  List<String> get requiredFields {
    final req = inputSchema['required'];
    if (req is List) {
      return req.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Argument definition for an MCP Prompt
class McpPromptArgument {
  final String name;
  final String description;
  final bool required;

  const McpPromptArgument({
    required this.name,
    this.description = '',
    this.required = false,
  });

  factory McpPromptArgument.fromJson(Map<String, dynamic> json) {
    return McpPromptArgument(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      required: json['required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'required': required,
      };
}

/// Definition of an MCP Prompt advertised by the remote server
class McpPromptDefinition {
  final String name;
  final String description;
  final List<McpPromptArgument> arguments;

  const McpPromptDefinition({
    required this.name,
    this.description = '',
    this.arguments = const [],
  });

  factory McpPromptDefinition.fromJson(Map<String, dynamic> json) {
    final argsRaw = json['arguments'];
    final List<McpPromptArgument> args = [];
    if (argsRaw is List) {
      for (final a in argsRaw) {
        if (a is Map<String, dynamic>) {
          args.add(McpPromptArgument.fromJson(a));
        }
      }
    }
    return McpPromptDefinition(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      arguments: args,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'arguments': arguments.map((a) => a.toJson()).toList(),
      };
}

/// Definition of an MCP Resource advertised by the remote server
class McpResourceDefinition {
  final String uri;
  final String name;
  final String description;
  final String? mimeType;

  const McpResourceDefinition({
    required this.uri,
    required this.name,
    this.description = '',
    this.mimeType,
  });

  factory McpResourceDefinition.fromJson(Map<String, dynamic> json) {
    return McpResourceDefinition(
      uri: json['uri']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mimeType: json['mimeType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
        'description': description,
        if (mimeType != null) 'mimeType': mimeType,
      };
}

/// Remote MCP Server configuration and capability snapshot
class McpServerModel {
  final String id;
  final String name;
  final String url;
  final McpTransportType transportType;
  final Map<String, String> headers;
  final String? systemPrompt;
  final String description;
  final int colorValue;
  final McpServerStatus status;
  final String? errorMessage;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic>? serverInfo;
  final List<McpToolDefinition> tools;
  final List<McpPromptDefinition> prompts;
  final List<McpResourceDefinition> resources;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  const McpServerModel({
    required this.id,
    required this.name,
    required this.url,
    this.transportType = McpTransportType.sse,
    this.headers = const {},
    this.systemPrompt,
    this.description = '',
    this.colorValue = 0xFF6366F1, // Default sleek Indigo
    this.status = McpServerStatus.disconnected,
    this.errorMessage,
    this.capabilities = const {},
    this.serverInfo,
    this.tools = const [],
    this.prompts = const [],
    this.resources = const [],
    required this.createdAt,
    this.lastConnectedAt,
  });

  Color get color => Color(colorValue);

  String get displayInitials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
    return 'MC';
  }

  McpServerModel copyWith({
    String? id,
    String? name,
    String? url,
    McpTransportType? transportType,
    Map<String, String>? headers,
    String? systemPrompt,
    String? description,
    int? colorValue,
    McpServerStatus? status,
    String? errorMessage,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? serverInfo,
    List<McpToolDefinition>? tools,
    List<McpPromptDefinition>? prompts,
    List<McpResourceDefinition>? resources,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
  }) {
    return McpServerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      transportType: transportType ?? this.transportType,
      headers: headers ?? this.headers,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      capabilities: capabilities ?? this.capabilities,
      serverInfo: serverInfo ?? this.serverInfo,
      tools: tools ?? this.tools,
      prompts: prompts ?? this.prompts,
      resources: resources ?? this.resources,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  factory McpServerModel.fromJson(Map<String, dynamic> json) {
    final toolsRaw = json['tools'];
    final List<McpToolDefinition> tools = [];
    if (toolsRaw is List) {
      for (final t in toolsRaw) {
        if (t is Map<String, dynamic>) {
          tools.add(McpToolDefinition.fromJson(t));
        }
      }
    }

    final promptsRaw = json['prompts'];
    final List<McpPromptDefinition> prompts = [];
    if (promptsRaw is List) {
      for (final p in promptsRaw) {
        if (p is Map<String, dynamic>) {
          prompts.add(McpPromptDefinition.fromJson(p));
        }
      }
    }

    final resourcesRaw = json['resources'];
    final List<McpResourceDefinition> resources = [];
    if (resourcesRaw is List) {
      for (final r in resourcesRaw) {
        if (r is Map<String, dynamic>) {
          resources.add(McpResourceDefinition.fromJson(r));
        }
      }
    }

    final headersMap = <String, String>{};
    if (json['headers'] is Map) {
      (json['headers'] as Map).forEach((key, value) {
        if (key != null && value != null) {
          headersMap[key.toString()] = value.toString();
        }
      });
    }

    return McpServerModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'MCP Server',
      url: json['url']?.toString() ?? '',
      transportType: McpTransportType.fromString(json['transportType']?.toString()),
      headers: headersMap,
      systemPrompt: json['systemPrompt']?.toString(),
      description: json['description']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
      status: McpServerStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => McpServerStatus.disconnected,
      ),
      errorMessage: json['errorMessage']?.toString(),
      capabilities: json['capabilities'] is Map<String, dynamic>
          ? json['capabilities'] as Map<String, dynamic>
          : const {},
      serverInfo: json['serverInfo'] is Map<String, dynamic>
          ? json['serverInfo'] as Map<String, dynamic>
          : null,
      tools: tools,
      prompts: prompts,
      resources: resources,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'transportType': transportType.name,
      'headers': headers,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
      'description': description,
      'colorValue': colorValue,
      'status': status.name,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'capabilities': capabilities,
      if (serverInfo != null) 'serverInfo': serverInfo,
      'tools': tools.map((t) => t.toJson()).toList(),
      'prompts': prompts.map((p) => p.toJson()).toList(),
      'resources': resources.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (lastConnectedAt != null) 'lastConnectedAt': lastConnectedAt!.toIso8601String(),
    };
  }
}
