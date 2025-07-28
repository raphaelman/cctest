package com.careconnect.controller;

import com.careconnect.dto.FirebaseNotificationRequest;
import com.careconnect.dto.NotificationResponse;
import com.careconnect.model.DeviceToken;
import com.careconnect.service.FirebaseNotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/v1/api/notifications")
@Tag(name = "Firebase Notifications", description = "Firebase Cloud Messaging for push notifications")
@SecurityRequirement(name = "Bearer Authentication")
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true", matchIfMissing = true)
public class NotificationController {
    
    @Autowired(required = false)
    private FirebaseNotificationService notificationService;
    
    @PostMapping("/send")
    @Operation(
        summary = "Send push notification",
        description = "Send a push notification to a specific device token"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Notification sent successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid request"),
        @ApiResponse(responseCode = "401", description = "Unauthorized")
    })
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN')")
    public ResponseEntity<NotificationResponse> sendNotification(
            @RequestBody FirebaseNotificationRequest request) {
        
        NotificationResponse response = notificationService.sendNotification(request);
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/send-bulk")
    @Operation(
        summary = "Send bulk push notifications",
        description = "Send push notifications to multiple device tokens"
    )
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN')")
    public ResponseEntity<List<NotificationResponse>> sendBulkNotifications(
            @RequestBody List<FirebaseNotificationRequest> requests) {
        
        List<NotificationResponse> responses = notificationService.sendBulkNotifications(requests);
        return ResponseEntity.ok(responses);
    }
    
    @PostMapping("/send-to-user/{userId}")
    @Operation(
        summary = "Send notification to user",
        description = "Send push notification to all devices of a specific user"
    )
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN')")
    public ResponseEntity<List<NotificationResponse>> sendNotificationToUser(
            @PathVariable Long userId,
            @RequestParam String title,
            @RequestParam String body,
            @RequestParam(required = false, defaultValue = "GENERAL") String notificationType,
            @RequestParam(required = false) Map<String, String> data) {
        
        List<NotificationResponse> responses = notificationService
                .sendNotificationToUser(userId, title, body, notificationType, data);
        return ResponseEntity.ok(responses);
    }
    
    @PostMapping("/vital-alert/{patientId}")
    @Operation(
        summary = "Send vital signs alert",
        description = "Send vital signs alert to patient's caregivers"
    )
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN') or hasRole('PATIENT')")
    public CompletableFuture<ResponseEntity<List<NotificationResponse>>> sendVitalAlert(
            @PathVariable Long patientId,
            @RequestParam String vitalType,
            @RequestParam String vitalValue,
            @RequestParam String alertLevel) {
        
        return notificationService.sendVitalAlert(patientId, vitalType, vitalValue, alertLevel)
                .thenApply(ResponseEntity::ok);
    }
    
    @PostMapping("/medication-reminder/{patientId}")
    @Operation(
        summary = "Send medication reminder",
        description = "Send medication reminder to patient"
    )
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN')")
    public CompletableFuture<ResponseEntity<List<NotificationResponse>>> sendMedicationReminder(
            @PathVariable Long patientId,
            @RequestParam String medicationName,
            @RequestParam String dosage,
            @RequestParam String scheduledTime) {
        
        return notificationService.sendMedicationReminder(patientId, medicationName, dosage, scheduledTime)
                .thenApply(ResponseEntity::ok);
    }
    
    @PostMapping("/emergency-alert/{patientId}")
    @Operation(
        summary = "Send emergency alert",
        description = "Send emergency alert to all caregivers and family members"
    )
    @PreAuthorize("hasRole('CAREGIVER') or hasRole('ADMIN') or hasRole('PATIENT') or hasRole('FAMILY_MEMBER')")
    public CompletableFuture<ResponseEntity<List<NotificationResponse>>> sendEmergencyAlert(
            @PathVariable Long patientId,
            @RequestParam String emergencyType,
            @RequestParam String location) {
        
        return notificationService.sendEmergencyAlert(patientId, emergencyType, location)
                .thenApply(ResponseEntity::ok);
    }
    
    @PostMapping("/register-token")
    @Operation(
        summary = "Register device token",
        description = "Register FCM device token for push notifications"
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Token registered successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid request"),
        @ApiResponse(responseCode = "401", description = "Unauthorized")
    })
    public ResponseEntity<Map<String, String>> registerDeviceToken(
            @RequestParam Long userId,
            @RequestParam String fcmToken,
            @RequestParam String deviceId,
            @RequestParam DeviceToken.DeviceType deviceType) {
        
        try {
            notificationService.registerDeviceToken(userId, fcmToken, deviceId, deviceType);
            return ResponseEntity.ok(Map.of("message", "Device token registered successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Failed to register device token: " + e.getMessage()));
        }
    }
    
    @DeleteMapping("/unregister-token")
    @Operation(
        summary = "Unregister device token",
        description = "Unregister FCM device token"
    )
    public ResponseEntity<Map<String, String>> unregisterDeviceToken(
            @RequestParam String fcmToken) {
        
        try {
            notificationService.unregisterDeviceToken(fcmToken);
            return ResponseEntity.ok(Map.of("message", "Device token unregistered successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Failed to unregister device token: " + e.getMessage()));
        }
    }
}
