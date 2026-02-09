import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/saved_pdf_model.dart';
import '../../services/password_storage_service.dart';

// EVENTS
abstract class PasswordManagerEvent extends Equatable {
  const PasswordManagerEvent();
  @override
  List<Object?> get props => [];
}

class LoadPasswords extends PasswordManagerEvent {}

class AddPassword extends PasswordManagerEvent {
  final String filePath;
  final String password;
  const AddPassword(this.filePath, this.password);
}

class RemovePassword extends PasswordManagerEvent {
  final String filePath;
  const RemovePassword(this.filePath);
}

class SearchPasswords extends PasswordManagerEvent {
  final String query;
  const SearchPasswords(this.query);
}

// STATES
abstract class PasswordManagerState extends Equatable {
  const PasswordManagerState();
  @override
  List<Object?> get props => [];
}

class PasswordManagerInitial extends PasswordManagerState {}

class PasswordManagerLoading extends PasswordManagerState {}

class PasswordManagerLoaded extends PasswordManagerState {
  final List<SavedPdfModel> passwords;
  final bool isFiltering;
  const PasswordManagerLoaded(this.passwords, {this.isFiltering = false});

  @override
  List<Object?> get props => [passwords, isFiltering];
}

class PasswordManagerError extends PasswordManagerState {
  final String message;
  const PasswordManagerError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class PasswordManagerBloc
    extends Bloc<PasswordManagerEvent, PasswordManagerState> {
  final PasswordStorageService _service = PasswordStorageService.instance;
  List<SavedPdfModel> _allPasswords = [];

  PasswordManagerBloc() : super(PasswordManagerInitial()) {
    on<LoadPasswords>(_onLoadPasswords);
    on<AddPassword>(_onAddPassword);
    on<RemovePassword>(_onRemovePassword);
    on<SearchPasswords>(_onSearchPasswords);
  }

  Future<void> _onLoadPasswords(
    LoadPasswords event,
    Emitter<PasswordManagerState> emit,
  ) async {
    emit(PasswordManagerLoading());
    try {
      _allPasswords = _service.getSavedPdfs();
      // Sort by date added desc
      _allPasswords.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      emit(PasswordManagerLoaded(_allPasswords));
    } catch (e) {
      emit(PasswordManagerError(e.toString()));
    }
  }

  Future<void> _onAddPassword(
    AddPassword event,
    Emitter<PasswordManagerState> emit,
  ) async {
    try {
      await _service.savePassword(event.filePath, event.password);
      add(LoadPasswords());
    } catch (e) {
      emit(PasswordManagerError('Failed to add password'));
    }
  }

  Future<void> _onRemovePassword(
    RemovePassword event,
    Emitter<PasswordManagerState> emit,
  ) async {
    try {
      await _service.removePassword(event.filePath);
      add(LoadPasswords());
    } catch (e) {
      emit(PasswordManagerError('Failed to delete password'));
    }
  }

  void _onSearchPasswords(
    SearchPasswords event,
    Emitter<PasswordManagerState> emit,
  ) {
    if (event.query.isEmpty) {
      emit(PasswordManagerLoaded(_allPasswords));
      return;
    }

    final filtered = _allPasswords
        .where(
          (p) => p.fileName.toLowerCase().contains(event.query.toLowerCase()),
        )
        .toList();

    emit(PasswordManagerLoaded(filtered, isFiltering: true));
  }
}
