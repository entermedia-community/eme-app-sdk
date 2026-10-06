import 'dart:convert';

/// Role of an MCP chat message
enum McpMessageRole {
  user,
  assistant,
  system,
  toolCall,
  toolResult,
  error;

  bool get isUser => this == McpMessageRole.user;
  bool get isAssistant => this == McpMessageRole.assistant;
  bool get isToolCall => this == McpMessageRole.toolCall;
  bool get isToolResult => this == McpMessageRole.toolResult;
  bool get isSystem => this == McpMessageRole.system;
  bool get isError => this == McpMessageRole.error;

  static McpMessageRole fromString(String? val) {
    if (val == null) return McpMessageRole.user;
    switch (val.toLowerCase().trim()) {
      case 'assistant':
        return McpMessageRole.assistant;
      case 'system':
        return McpMessageRole.system;
      case 'toolcall':
      case 'tool_call':
        return McpMessageRole.toolCall;
      case 'toolresult':
      case 'tool_result':
        return McpMessageRole.toolResult;
      case 'error':
        return McpMessageRole.error;
      case 'user':
      default:
        return McpMessageRole.user;
    }
  }
}

/// Message exchanged in an MCP Server Chat conversation
class McpChatMessage {
  final String id;
  final String serverId;
  final McpMessageRole role;
  final String content;
  final String? toolName;
  final Map<String, dynamic>? toolArguments;
  final dynamic toolResult;
  final bool isError;
  final DateTime timestamp;
  final int? latencyMs;
  final Map<String, dynamic>? metadata;

  const McpChatMessage({
    required this.id,
    required this.serverId,
    required this.role,
    required this.content,
    this.toolName,
    this.toolArguments,
    this.toolResult,
    this.isError = false,
    required this.timestamp,
    this.latencyMs,
    this.metadata,
  });

  /// Formatted JSON string of tool arguments
  String? get formattedArguments {
    if (toolArguments == null) return null;
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toolArguments);
    } catch (_) {
      return toolArguments.toString();
    }
  }

  /// Formatted JSON/Text string of tool result
  String? get formattedResult {
    if (toolResult == null) return null;
    if (toolResult is String) return toolResult as String;
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toolResult);
    } catch (_) {
      return toolResult.toString();
    }
  }

  McpChatMessage copyWith({
    String? id,
    String? serverId,
    McpMessageRole? role,
    String? content,
    String? toolName,
    Map<String, dynamic>? toolArguments,
    dynamic toolResult,
    bool? isError,
    DateTime? timestamp,
    int? latencyMs,
    Map<String, dynamic>? metadata,
  }) {
    return McpChatMessage(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      role: role ?? this.role,
      content: content ?? this.content,
      toolName: toolName ?? this.toolName,
      toolArguments: toolArguments ?? this.toolArguments,
      toolResult: toolResult ?? this.toolResult,
      isError: isError ?? this.isError,
      timestamp: timestamp ?? this.timestamp,
      latencyMs: latencyMs ?? this.latencyMs,
      metadata: metadata ?? this.metadata,
    );
  }

  factory McpChatMessage.fromJson(Map<String, dynamic> json) {
    return McpChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      serverId: json['serverId']?.toString() ?? '',
      role: McpMessageRole.fromString(json['role']?.toString()),
      content: json['content']?.toString() ?? '',
      toolName: json['toolName']?.toString(),
      toolArguments: json['toolArguments'] is Map<String, dynamic>
          ? json['toolArguments'] as Map<String, dynamic>
          : null,
      toolResult: json['toolResult'],
      isError: json['isError'] == true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverId': serverId,
      'role': role.name,
      'content': content,
      if (toolName != null) 'toolName': toolName,
      if (toolArguments != null) 'toolArguments': toolArguments,
      if (toolResult != null) 'toolResult': toolResult,
      'isError': isError,
      'timestamp': timestamp.toIso8601String(),
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
