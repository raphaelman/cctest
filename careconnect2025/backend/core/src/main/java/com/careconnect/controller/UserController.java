package com.careconnect.controller;

import com.careconnect.dto.UserResponse;
import com.careconnect.model.User;
import com.careconnect.repository.UserRepository;
import com.careconnect.service.UserPasswordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.Map;

import java.util.Collections;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/v1/api/users")
@Tag(name = "User Management", description = "User management endpoints including search and password management")
public class UserController {
    @Autowired
    private UserPasswordService userPasswordService;

    @Autowired
    private UserRepository userRepo;

    /**
     * Reset password for user (caregiver or patient) using username (email) and reset token
     */
    @PostMapping("/reset-password")
    @Operation(
        summary = "Reset user password",
        description = "Reset password for any user (caregiver or patient) using username (email), reset token, and new password. This endpoint completes the password reset flow after the user receives a reset token via email.",
        tags = {"Authentication", "User Management"},
        security = {}, // No authentication required for password reset
        requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
            description = "Password reset request containing username (email), reset token, and new password",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = com.careconnect.dto.ResetPasswordRequest.class),
                examples = @ExampleObject(
                    name = "Password Reset Example",
                    value = """
                    {
                        "username": "user@example.com",
                        "resetToken": "abc123-reset-token-xyz789",
                        "newPassword": "NewSecurePassword123!"
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Password reset successful",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = """
                    {
                        "message": "Password updated successfully"
                    }
                    """)
            )
        ),
        @ApiResponse(responseCode = "400", description = "Invalid request or expired token",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = """
                    {
                        "error": "Invalid or expired reset token"
                    }
                    """)
            )
        )
    })
    public ResponseEntity<?> resetPassword(@RequestBody com.careconnect.dto.ResetPasswordRequest req) {
        try {
            userPasswordService.resetPasswordWithToken(req.getUsername(), req.getResetToken(), req.getNewPassword());
            return ResponseEntity.ok(Collections.singletonMap("message", "Password updated successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Collections.singletonMap("error", e.getMessage()));
        }
    }


    /**
     * Set up password for new users using verification token (from patient registration)
     */
    @PostMapping("/setup-password")
    @Operation(
        summary = "Set up password for new user",
        description = "Set up password for new users (patients) using verification token from registration email. This is different from password reset - it's for users who haven't set their password yet.",
        tags = {"Authentication", "User Management"},
        security = {}, // No authentication required for password setup
        requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
            description = "Password setup request containing username (email), verification token, and new password",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = com.careconnect.dto.SetupPasswordRequest.class),
                examples = @ExampleObject(
                    name = "Password Setup Example",
                    value = """
                    {
                        "username": "patient@example.com",
                        "verificationToken": "c4de0569-80a6-44f5-a6ad-dd0adba19c6e",
                        "newPassword": "MyNewPassword123!"
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Password setup successful",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = """
                    {
                        "message": "Password setup completed successfully"
                    }
                    """)
            )
        ),
        @ApiResponse(responseCode = "400", description = "Invalid request or token",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = """
                    {
                        "error": "Invalid or expired verification token"
                    }
                    """)
            )
        )
    })
    public ResponseEntity<?> setupPassword(@RequestBody com.careconnect.dto.SetupPasswordRequest req) {
        try {
            userPasswordService.setupPasswordWithVerificationToken(req.username(), req.verificationToken(), req.newPassword());
            return ResponseEntity.ok(Collections.singletonMap("message", "Password setup completed successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Collections.singletonMap("error", e.getMessage()));
        }
    }

    @GetMapping("/search")
    public ResponseEntity<List<UserResponse>> searchUsers(
            @RequestParam String query,
            @RequestParam Long currentUserId) {

        List<User> users = userRepo.findByNameContainingIgnoreCaseOrEmailContainingIgnoreCase(query, query);

        Optional<User> currentUserOpt = userRepo.findById(currentUserId);
        if (currentUserOpt.isEmpty()) {
            return ResponseEntity.badRequest().body(Collections.emptyList());
        }

        User currentUser = currentUserOpt.get();


        List<UserResponse> response = users.stream()
                .filter(u -> !(
                        u.getId().equals(currentUserId) &&
                                u.getEmail().equalsIgnoreCase(currentUser.getEmail()) &&
                                u.getRole().equals(currentUser.getRole())
                )) // exclude self (same ID + same role + same email)
                .map(u -> new UserResponse(
                        u.getId(),
                        u.getName(),
                        u.getEmail(),
                        u.getRole(),
                        Boolean.TRUE.equals(u.getIsVerified()),
                        u.getProfileImageUrl(),
                        u.getStatus()
                ))
                .toList();

        return ResponseEntity.ok(response);
    }

    @GetMapping("/check-email")
    @Operation(
        summary = "Check if email exists",
        description = "Check if a user exists with the given email address and return their role if they do",
        tags = {"User Management"},
        security = {}
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Email check completed",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = """
                    {
                        "exists": true,
                        "role": "PATIENT"
                    }
                    """)
            )
        )
    })
    public ResponseEntity<?> checkEmailExists(@RequestParam String email) {
        Optional<User> userOpt = userRepo.findByEmail(email);
        
        if (userOpt.isPresent()) {
            User user = userOpt.get();
            return ResponseEntity.ok(Map.of(
                "exists", true,
                "role", user.getRole(),
                "userId", user.getId()
            ));
        } else {
            return ResponseEntity.ok(Map.of(
                "exists", false
            ));
        }
    }
}
