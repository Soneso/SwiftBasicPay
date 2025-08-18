//
//  KycView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import Observation
import AlertToast

// MARK: - View Model

@Observable
final class KycViewModel {
    // UI State
    var selectedItem: KycEntry?
    var isEditing = false
    var editedValue = ""
    var isSaving = false
    var error: String?
    var showToast = false
    var toastMessage = ""
    var isRefreshing = false
    var itemToDelete: KycEntry?
    var showDeleteConfirmation = false
    
    // Form validation
    var isFormValid: Bool {
        !editedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editedValue.count <= 100
    }
    
    func startEditing(item: KycEntry) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedItem = item
            editedValue = item.val
            isEditing = true
            error = nil
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    func confirmDelete(item: KycEntry) {
        itemToDelete = item
        showDeleteConfirmation = true
    }
    
    func cancelEditing() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing = false
            selectedItem = nil
            editedValue = ""
            error = nil
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @MainActor
    func saveEditedValue(dashboardData: DashboardData) async {
        guard let item = selectedItem else { return }
        
        isSaving = true
        error = nil
        
        do {
            // Save using proper KycManager method
            try await dashboardData.kycManagerDirect.updateKycEntry(id: item.id, value: editedValue)
            
            // Success feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Show toast
            toastMessage = "KYC data updated successfully"
            showToast = true
            
            // Reset form
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditing = false
                selectedItem = nil
                editedValue = ""
            }
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
            
            // Error feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
        
        isSaving = false
    }
    
    @MainActor
    func refreshData(dashboardData: DashboardData) async {
        isRefreshing = true
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        await dashboardData.loadUserKycData()
        
        // Add slight delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isRefreshing = false
    }
    
    @MainActor
    func deleteValue(dashboardData: DashboardData) async {
        guard let item = itemToDelete else { return }
        
        do {
            // Delete using proper KycManager method
            try await dashboardData.kycManagerDirect.deleteKycEntry(id: item.id)
            
            // Success feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Show toast
            toastMessage = "KYC data cleared"
            showToast = true
            
            itemToDelete = nil
        } catch {
            self.error = "Failed to clear data: \(error.localizedDescription)"
            
            // Error feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
}

// MARK: - Main View

@MainActor
struct KycView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: KycViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    init() {
        self._viewModel = State(wrappedValue: KycViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if dashboardData.userKycData.isEmpty && !viewModel.isRefreshing {
                    KycEmptyStateView()
                } else {
                    mainContent
                        .blur(radius: viewModel.isEditing ? 3 : 0)
                        .allowsHitTesting(!viewModel.isEditing)
                }
                
                // Floating edit form
                if viewModel.isEditing {
                    editFormOverlay
                }
            }
            .navigationTitle("KYC Data")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData(dashboardData: dashboardData)
            }
            .toast(isPresenting: $viewModel.showToast) {
                AlertToast(
                    displayMode: .banner(.slide),
                    type: .complete(.green),
                    title: viewModel.toastMessage
                )
            }
            .confirmationDialog(
                "Clear this KYC field?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    Task {
                        await viewModel.deleteValue(dashboardData: dashboardData)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.itemToDelete = nil
                }
            } message: {
                if let item = viewModel.itemToDelete {
                    Text("This will remove the value for \(item.keyLabel)")
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                KycHeaderCard()
                    .padding(.horizontal)
                
                // KYC Items
                LazyVStack(spacing: 12) {
                    ForEach(dashboardData.userKycData) { item in
                        KycItemCard(
                            item: item,
                            onEdit: { viewModel.startEditing(item: item) },
                            onDelete: { viewModel.confirmDelete(item: item) }
                        )
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Edit Form Overlay
    
    private var editFormOverlay: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isSaving {
                        viewModel.cancelEditing()
                    }
                }
            
            // Edit form
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Form content
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text("Edit \(viewModel.selectedItem?.keyLabel ?? "")")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter value", text: $viewModel.editedValue)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                            .disabled(viewModel.isSaving)
                            .onChange(of: viewModel.editedValue) { _, newValue in
                                if newValue.count > 100 {
                                    viewModel.editedValue = String(newValue.prefix(100))
                                }
                            }
                        
                        HStack {
                            if let error = viewModel.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("\(viewModel.editedValue.count)/100")
                                    .font(.caption)
                                    .foregroundColor(viewModel.editedValue.count > 80 ? .orange : .secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: { viewModel.cancelEditing() }) {
                            Text("Cancel")
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .disabled(viewModel.isSaving)
                        
                        Button(action: {
                            Task {
                                await viewModel.saveEditedValue(dashboardData: dashboardData)
                            }
                        }) {
                            HStack {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Save")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(viewModel.isFormValid ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(viewModel.isFormValid ? .white : .gray)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isSaving)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .frame(maxWidth: 400)
            .padding(.horizontal, 20)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Components

struct KycHeaderCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your KYC Information")
                        .font(.headline)
                    Text("Manage your identity verification data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct KycItemCard: View {
    let item: KycEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconForField(item.id))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.keyLabel)
                    .font(.subheadline.weight(.medium))
                
                if item.val.isEmpty {
                    Text("Not provided")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(item.val)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if !item.val.isEmpty {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(.systemGray6)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func iconForField(_ fieldId: String) -> String {
        switch fieldId.lowercased() {
        case let id where id.contains("name"):
            return "person.fill"
        case let id where id.contains("email"):
            return "envelope.fill"
        case let id where id.contains("phone"):
            return "phone.fill"
        case let id where id.contains("address"):
            return "house.fill"
        case let id where id.contains("birth") || id.contains("dob"):
            return "calendar"
        case let id where id.contains("id") || id.contains("passport"):
            return "doc.text.fill"
        case let id where id.contains("country"):
            return "globe"
        case let id where id.contains("city"):
            return "building.2.fill"
        default:
            return "doc.fill"
        }
    }
}

struct KycEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No KYC Data")
                    .font(.title2.weight(.semibold))
                
                Text("Your identity verification information will appear here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Pull to refresh")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading Skeleton

struct KycSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header skeleton
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(height: 80)
                    .padding(.horizontal)
                    .redacted(reason: .placeholder)
                    .shimmering()
                
                // Items skeleton
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 76)
                        .padding(.horizontal)
                        .redacted(reason: .placeholder)
                        .shimmering()
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 300 : -300)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            )
            .onAppear {
                isAnimating = true
            }
    }
}