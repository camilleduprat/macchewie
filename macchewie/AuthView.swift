//
//  AuthView.swift
//  macchewie
//
//  Created by AI Assistant on 10/09/2025.
//

import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLoading = false
    @State private var emailStored = false
    @Binding var userEmail: String
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Welcome to MacChewie")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your email to sync with your ChewieAI account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Email input form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("your@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                        .font(.system(size: 16))
                        .padding(.vertical, 4)
                }
                
                Button(action: {
                    Task {
                        await signInWithEmail()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                        }
                        Text(isLoading ? "Signing in..." : "Continue")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(email.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || email.isEmpty)
                .buttonStyle(.plain)
            }
            
            // Error message
            if showError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Footer
            Text("Your data will be synced with your ChewieAI web account")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 420, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func signInWithEmail() async {
        isLoading = true
        errorMessage = ""
        showError = false
        
        // Simple email-based sign in - no auth required
        await MainActor.run {
            // Store email for use in the app
            UserDefaults.standard.set(email, forKey: "user_email")
            print("✅ [AuthView] Email stored: \(email)")
            emailStored = true
            
            // Update the parent view's userEmail binding
            userEmail = email
        }
        
        // Add a small delay to show the loading state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    AuthView(userEmail: .constant(""))
}