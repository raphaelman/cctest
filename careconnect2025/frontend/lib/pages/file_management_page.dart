import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/comprehensive_file_service.dart';
import '../services/enhanced_file_service.dart';
import '../providers/user_provider.dart';
import '../config/theme/app_theme.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/common_drawer.dart';

/// Comprehensive file management page
class FileManagementPage extends StatefulWidget {
  const FileManagementPage({super.key});

  @override
  State<FileManagementPage> createState() => _FileManagementPageState();
}

class _FileManagementPageState extends State<FileManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<UserFileDTO> _allFiles = [];
  List<UserFileDTO> _filteredFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  FileCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      if (user == null) return;

      final files = await ComprehensiveFileService.getAllUserFiles(
        user.id,
        params: FileQueryParams(size: 100, sort: 'createdAt,desc'),
      );

      setState(() {
        _allFiles = files;
        _filteredFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading files: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _filterFiles() {
    setState(() {
      _filteredFiles = _allFiles.where((file) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            file.originalFilename.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (file.description?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);

        final matchesCategory =
            _selectedCategory == null ||
            file.fileCategory == _selectedCategory!.value;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    if (user == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isCaregiver = user.role.toUpperCase() == 'CAREGIVER';
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'My Files'),
            Tab(icon: Icon(Icons.cloud_upload), text: 'Upload'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      drawer: const CommonDrawer(currentRoute: '/file-management'),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFilesTab(), _buildUploadTab(), _buildAnalyticsTab()],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFiles.isEmpty
              ? _buildEmptyState()
              : _buildFilesList(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search files...',
              hintText: 'Search by filename or description',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _filterFiles();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _filterFiles();
            },
          ),
          const SizedBox(height: 12),

          // Category filter
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FileCategory?>(
                  value: _selectedCategory,
                  decoration: AppTheme.inputDecoration('Filter by category'),
                  items: [
                    const DropdownMenuItem<FileCategory?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ...FileCategory.values.map((category) {
                      return DropdownMenuItem<FileCategory?>(
                        value: category,
                        child: Row(
                          children: [
                            Text(category.icon),
                            const SizedBox(width: 8),
                            Text(category.displayName),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (FileCategory? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                    _filterFiles();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh files',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'No files match your filters'
                : 'No files uploaded yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Try adjusting your search or filter criteria'
                : 'Start by uploading your first file using the Upload tab',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty && _selectedCategory == null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Files'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredFiles.length,
        itemBuilder: (context, index) {
          final file = _filteredFiles[index];
          return _buildFileCard(file);
        },
      ),
    );
  }

  Widget _buildFileCard(UserFileDTO file) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            file.fileIcon,
            style:
                theme.textTheme.titleLarge?.copyWith(fontSize: 20) ??
                const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          file.originalFilename,
          style:
              theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ) ??
              AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  file.categoryDisplayName,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(' • ', style: theme.textTheme.bodyMedium),
                Text(
                  _formatFileSize(file.fileSize),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(' • ', style: theme.textTheme.bodyMedium),
                Text(
                  _formatDate(file.createdAt),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (file.description != null && file.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                file.description!,
                style: theme.textTheme.bodySmall ?? AppTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (String action) => _handleFileAction(action, file),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'download',
              child: ListTile(
                leading: Icon(Icons.download, color: theme.iconTheme.color),
                title: Text('Download', style: theme.textTheme.bodyMedium),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (file.isPreviewable)
              PopupMenuItem(
                value: 'preview',
                child: ListTile(
                  leading: Icon(Icons.visibility, color: theme.iconTheme.color),
                  title: Text('Preview', style: theme.textTheme.bodyMedium),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            PopupMenuItem(
              value: 'info',
              child: ListTile(
                leading: Icon(Icons.info, color: theme.iconTheme.color),
                title: Text('Info', style: theme.textTheme.bodyMedium),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: theme.colorScheme.error),
                title: Text(
                  'Delete',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick upload buttons
          QuickUploadButtons(
            onUploadSuccess: (response) {
              _loadFiles(); // Refresh the files list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File uploaded: ${response.originalFilename}'),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Full upload widget with improved feedback
          FileUploadWidget(
            onUploadSuccess: (response) {
              _loadFiles(); // Refresh the files list
            },
            onUploadError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Upload instructions and warning
          Card(
            color: Theme.of(context).colorScheme.surface,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'To upload a file, select a category and choose a file. The upload button will be enabled when ready.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final categories = <String, int>{};
    final totalSize = _allFiles.fold<int>(
      0,
      (sum, file) => sum + file.fileSize,
    );

    // Count files by category
    for (final file in _allFiles) {
      categories[file.categoryDisplayName] =
          (categories[file.categoryDisplayName] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('File Analytics', style: AppTheme.headingMedium),
          const SizedBox(height: 24),

          // Overview cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Files',
                  value: '${_allFiles.length}',
                  icon: Icons.folder,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Size',
                  value: _formatFileSize(totalSize),
                  icon: Icons.storage,
                  color: AppTheme.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category breakdown
          const Text('Files by Category', style: AppTheme.headingSmall),
          const SizedBox(height: 12),
          ...categories.entries.map((entry) {
            return Card(
              child: ListTile(
                title: Text(entry.key),
                trailing: CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 16,
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppTheme.headingMedium.copyWith(color: color)),
            Text(title, style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _handleFileAction(String action, UserFileDTO file) async {
    switch (action) {
      case 'download':
        await _downloadFile(file);
        break;
      case 'preview':
        _previewFile(file);
        break;
      case 'info':
        _showFileInfo(file);
        break;
      case 'delete':
        _deleteFile(file);
        break;
    }
  }

  Future<void> _downloadFile(UserFileDTO file) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${file.originalFilename}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final fileData = await EnhancedFileService.downloadFile(file.id);
      if (fileData != null) {
        // In a real app, you'd save the file to the device
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${file.originalFilename}'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _previewFile(UserFileDTO file) {
    // In a real app, you'd implement file preview
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.originalFilename),
        content: const Text('Preview functionality would be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFileInfo(UserFileDTO file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.originalFilename),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Category', file.categoryDisplayName),
              _buildInfoRow('Size', _formatFileSize(file.fileSize)),
              _buildInfoRow('Type', file.contentType),
              _buildInfoRow('Created', _formatDate(file.createdAt)),
              _buildInfoRow('Updated', _formatDate(file.updatedAt)),
              if (file.description != null && file.description!.isNotEmpty)
                _buildInfoRow('Description', file.description!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  void _deleteFile(UserFileDTO file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
          'Are you sure you want to delete "${file.originalFilename}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final success = await EnhancedFileService.deleteFile(file.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted ${file.originalFilename}'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                _loadFiles(); // Refresh the list
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete ${file.originalFilename}'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            style: AppTheme.dangerButtonStyle,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
