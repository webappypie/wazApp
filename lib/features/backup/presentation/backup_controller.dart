// lib/features/backup/presentation/backup_controller.dart
//
// Riverpod Controller for managing Google Drive Cloud Backup (REQ-BAK-01..03, P-01..03).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/backup/cloud_backup_service.dart';
import '../data/backup_repository.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(cloudBackupServiceProvider);
  return BackupRepository(db: db, backupService: service);
});

class BackupState {
  final BackupCategoryFilter selectedFilter;
  final List<BackupMediaItem> candidateItems;
  final bool isLoadingCandidates;
  final CloudAuthStatus authStatus;
  final BackupProgressSnapshot progress;
  final bool isCustomSelection;

  const BackupState({
    this.selectedFilter = BackupCategoryFilter.all,
    this.candidateItems = const [],
    this.isLoadingCandidates = false,
    this.authStatus = const CloudAuthDisconnected(),
    this.progress = const BackupProgressSnapshot(),
    this.isCustomSelection = false,
  });

  int get totalCandidateBytes =>
      candidateItems.fold<int>(0, (sum, i) => sum + i.sizeBytes);

  int get totalCandidateCount => candidateItems.length;

  BackupState copyWith({
    BackupCategoryFilter? selectedFilter,
    List<BackupMediaItem>? candidateItems,
    bool? isLoadingCandidates,
    CloudAuthStatus? authStatus,
    BackupProgressSnapshot? progress,
    bool? isCustomSelection,
  }) {
    return BackupState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      candidateItems: candidateItems ?? this.candidateItems,
      isLoadingCandidates: isLoadingCandidates ?? this.isLoadingCandidates,
      authStatus: authStatus ?? this.authStatus,
      progress: progress ?? this.progress,
      isCustomSelection: isCustomSelection ?? this.isCustomSelection,
    );
  }
}

class BackupController extends Notifier<BackupState> {
  StreamSubscription<CloudAuthStatus>? _authSub;
  StreamSubscription<BackupProgressSnapshot>? _progressSub;

  @override
  BackupState build() {
    final repo = ref.watch(backupRepositoryProvider);

    _authSub?.cancel();
    _progressSub?.cancel();

    _authSub = repo.service.authStateChanges.listen((status) {
      state = state.copyWith(authStatus: status);
    });

    _progressSub = repo.service.progressStream.listen((snapshot) {
      state = state.copyWith(progress: snapshot);
    });

    ref.onDispose(() {
      _authSub?.cancel();
      _progressSub?.cancel();
    });

    // Schedule initial candidate load
    Future.microtask(() => loadCandidates(BackupCategoryFilter.all));

    return BackupState(
      authStatus: repo.service.currentAuthStatus,
      progress: repo.service.currentSnapshot,
    );
  }

  BackupRepository get _repository => ref.read(backupRepositoryProvider);

  Future<void> loadCandidates(BackupCategoryFilter filter) async {
    state = state.copyWith(
      selectedFilter: filter,
      isLoadingCandidates: true,
      isCustomSelection: false,
    );
    try {
      final items = await _repository.getCandidateItems(filter: filter);
      state = state.copyWith(
        candidateItems: items,
        isLoadingCandidates: false,
      );
    } catch (_) {
      state = state.copyWith(
        candidateItems: const [],
        isLoadingCandidates: false,
      );
    }
  }

  void setCustomSelection(List<BackupMediaItem> items) {
    state = state.copyWith(
      candidateItems: items,
      isCustomSelection: true,
      isLoadingCandidates: false,
    );
  }

  Future<void> signIn() async {
    await _repository.service.signIn();
  }

  Future<void> signOut() async {
    await _repository.service.signOut();
  }

  Future<void> startBackup() async {
    if (state.candidateItems.isEmpty) return;
    await _repository.service.startBackup(items: state.candidateItems);
  }

  void pauseBackup() {
    _repository.service.pauseBackup();
  }

  void resumeBackup() {
    _repository.service.resumeBackup();
  }

  void cancelBackup() {
    _repository.service.cancelBackup();
  }

  Future<void> retryFailed() async {
    await _repository.service.retryFailed();
  }

  /// REQ-BAK-03: Never delete local originals after upload.
  /// Post-backup CTA reads "Review originals", not "Delete originals".
  void reviewOriginals(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutes.clean);
      }
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }
}

final backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);
