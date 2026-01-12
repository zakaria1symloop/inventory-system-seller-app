import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/client_model.dart';
import '../../data/services/api_service.dart';
import '../../core/theme/app_theme.dart';

final clientsProvider = FutureProvider.family<List<ClientModel>, String?>((ref, search) async {
  debugPrint('[CLIENTS] Fetching...');
  final response = await ApiService.instance.getClients(params: search != null && search.isNotEmpty ? {"search": search} : null);
  final data = response.data;
  debugPrint('[CLIENTS] Data type: ${data.runtimeType}');

  final List clientsList = data is Map ? (data["data"] ?? []) : data;
  debugPrint('[CLIENTS] Count: ${clientsList.length}');

  if (clientsList.isNotEmpty) {
    debugPrint('[CLIENTS] Sample: ${clientsList[0]}');
  }

  final result = <ClientModel>[];
  for (var c in clientsList) {
    try {
      result.add(ClientModel.fromJson(c));
    } catch (e) {
      debugPrint('[CLIENTS] ERROR: $e');
      debugPrint('[CLIENTS] DATA: $c');
    }
  }
  return result;
});

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider(_searchQuery.isEmpty ? null : _searchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "بحث عن عميل...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        Expanded(
          child: clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("لا يوجد عملاء", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clientsProvider(_searchQuery.isEmpty ? null : _searchQuery));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return _ClientCard(client: client);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint("[CLIENTS] UI Error: $error");
              return Center(child: Text("Error: $error"));
            },
          ),
        ),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ClientModel client;

  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  client.name.isNotEmpty ? client.name.substring(0, 1) : "?",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (client.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(client.phone!, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                "${client.balance.toStringAsFixed(0)} د.ج",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: client.balance > 0 ? AppTheme.dangerColor : AppTheme.successColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
