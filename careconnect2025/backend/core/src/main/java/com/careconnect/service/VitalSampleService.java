package com.careconnect.service;

import com.careconnect.dto.VitalSampleDTO;
import com.careconnect.model.Patient;
import com.careconnect.model.VitalSample;
import com.careconnect.repository.PatientRepository;
import com.careconnect.repository.VitalSampleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.Period;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class VitalSampleService {
    
    private final VitalSampleRepository vitalSampleRepository;
    private final PatientRepository patientRepository;
    
    @Autowired(required = false)
    private FirebaseNotificationService notificationService;
    
    /**
     * Create a new vital sample
     */
    @Transactional
    public VitalSampleDTO createVitalSample(VitalSampleDTO dto) {
        Patient patient = patientRepository.findById(dto.patientId())
            .orElseThrow(() -> new IllegalArgumentException("Patient not found with id: " + dto.patientId()));
        
        VitalSample vitalSample = VitalSample.builder()
            .patient(patient)
            .timestamp(dto.timestamp() != null ? dto.timestamp() : Instant.now())
            .heartRate(dto.heartRate())
            .spo2(dto.spo2())
            .systolic(dto.systolic())
            .diastolic(dto.diastolic())
            .weight(dto.weight())
            .moodValue(dto.moodValue())
            .painValue(dto.painValue())
            .build();
        
        VitalSample saved = vitalSampleRepository.save(vitalSample);
        
        // Check for vital alerts and send notifications asynchronously
        checkAndSendVitalAlerts(saved);
        
        return mapToDTO(saved);
    }
    
    /**
     * Update an existing vital sample
     */
    @Transactional
    public VitalSampleDTO updateVitalSample(Long id, VitalSampleDTO dto) {
        VitalSample existing = vitalSampleRepository.findById(id)
            .orElseThrow(() -> new IllegalArgumentException("VitalSample not found with id: " + id));
        
        // Update only non-null fields
        if (dto.timestamp() != null) {
            existing.setTimestamp(dto.timestamp());
        }
        if (dto.heartRate() != null) {
            existing.setHeartRate(dto.heartRate());
        }
        if (dto.spo2() != null) {
            existing.setSpo2(dto.spo2());
        }
        if (dto.systolic() != null) {
            existing.setSystolic(dto.systolic());
        }
        if (dto.diastolic() != null) {
            existing.setDiastolic(dto.diastolic());
        }
        if (dto.weight() != null) {
            existing.setWeight(dto.weight());
        }
        if (dto.moodValue() != null) {
            existing.setMoodValue(dto.moodValue());
        }
        if (dto.painValue() != null) {
            existing.setPainValue(dto.painValue());
        }
        
        VitalSample updated = vitalSampleRepository.save(existing);
        return mapToDTO(updated);
    }
    
    /**
     * Get vital samples for a patient within a time period
     */
    public List<VitalSampleDTO> getVitalSamples(Long patientId, Period period) {
        Patient patient = patientRepository.findById(patientId)
            .orElseThrow(() -> new IllegalArgumentException("Patient not found with id: " + patientId));
        
        Instant fromTime = Instant.now().minus(period);
        Instant toTime = Instant.now();
        
        return vitalSampleRepository.findByPatientAndTimestampBetweenOrderByTimestampDesc(
                patient, fromTime, toTime)
            .stream()
            .map(this::mapToDTO)
            .toList();
    }
    
    /**
     * Get a specific vital sample by ID
     */
    public Optional<VitalSampleDTO> getVitalSample(Long id) {
        return vitalSampleRepository.findById(id)
            .map(this::mapToDTO);
    }
    
    /**
     * Delete a vital sample
     */
    @Transactional
    public void deleteVitalSample(Long id) {
        if (!vitalSampleRepository.existsById(id)) {
            throw new IllegalArgumentException("VitalSample not found with id: " + id);
        }
        vitalSampleRepository.deleteById(id);
    }
    
    /**
     * Get the latest vital sample for a patient
     */
    public Optional<VitalSampleDTO> getLatestVitalSample(Long patientId) {
        Patient patient = patientRepository.findById(patientId)
            .orElseThrow(() -> new IllegalArgumentException("Patient not found with id: " + patientId));
        
        return vitalSampleRepository.findFirstByPatientOrderByTimestampDesc(patient)
            .map(this::mapToDTO);
    }
    
    /**
     * Map VitalSample entity to DTO
     */
    private VitalSampleDTO mapToDTO(VitalSample vitalSample) {
        return VitalSampleDTO.builder()
            .id(vitalSample.getId())
            .patientId(vitalSample.getPatient().getId())
            .timestamp(vitalSample.getTimestamp())
            .heartRate(vitalSample.getHeartRate())
            .spo2(vitalSample.getSpo2())
            .systolic(vitalSample.getSystolic())
            .diastolic(vitalSample.getDiastolic())
            .weight(vitalSample.getWeight())
            .moodValue(vitalSample.getMoodValue())
            .painValue(vitalSample.getPainValue())
            .build();
    }
    
    /**
     * Check vital signs and send alerts if necessary
     */
    private void checkAndSendVitalAlerts(VitalSample vitalSample) {
        try {
            Long patientId = vitalSample.getPatient().getId();
            
            // Check heart rate alerts
            if (vitalSample.getHeartRate() != null) {
                String alertLevel = determineHeartRateAlert(vitalSample.getHeartRate());
                if (!"NORMAL".equals(alertLevel)) {
                    sendVitalAlertIfEnabled(
                        patientId, 
                        "Heart Rate", 
                        vitalSample.getHeartRate() + " bpm", 
                        alertLevel
                    );
                }
            }
            
            // Check SpO2 alerts
            if (vitalSample.getSpo2() != null) {
                String alertLevel = determineSpO2Alert(vitalSample.getSpo2());
                if (!"NORMAL".equals(alertLevel)) {
                    sendVitalAlertIfEnabled(
                        patientId, 
                        "Blood Oxygen (SpO2)", 
                        vitalSample.getSpo2() + "%", 
                        alertLevel
                    );
                }
            }
            
            // Check blood pressure alerts
            if (vitalSample.getSystolic() != null || vitalSample.getDiastolic() != null) {
                String alertLevel = determineBPAlert(vitalSample.getSystolic(), vitalSample.getDiastolic());
                if (!"NORMAL".equals(alertLevel)) {
                    String bpValue = (vitalSample.getSystolic() != null ? vitalSample.getSystolic() : "?") + 
                                   "/" + (vitalSample.getDiastolic() != null ? vitalSample.getDiastolic() : "?");
                    sendVitalAlertIfEnabled(
                        patientId, 
                        "Blood Pressure", 
                        bpValue + " mmHg", 
                        alertLevel
                    );
                }
            }
            
            // Check mood alerts (severe depression or anxiety)
            if (vitalSample.getMoodValue() != null && vitalSample.getMoodValue() <= 2) {
                sendVitalAlertIfEnabled(
                    patientId, 
                    "Mood", 
                    "Low mood score: " + vitalSample.getMoodValue(), 
                    "HIGH"
                );
            }
            
            // Check pain alerts (severe pain)
            if (vitalSample.getPainValue() != null && vitalSample.getPainValue() >= 8) {
                sendVitalAlertIfEnabled(
                    patientId, 
                    "Pain Level", 
                    "High pain score: " + vitalSample.getPainValue(), 
                    "HIGH"
                );
            }
            
        } catch (Exception e) {
            // Log error but don't fail the vital recording
            System.err.println("Error sending vital alerts: " + e.getMessage());
        }
    }
    
    private String determineHeartRateAlert(Double heartRate) {
        if (heartRate == null) return "NORMAL";
        if (heartRate < 60) return "LOW";
        if (heartRate > 100) return "HIGH"; 
        if (heartRate > 120) return "CRITICAL";
        return "NORMAL";
    }
    
    private String determineSpO2Alert(Double spo2) {
        if (spo2 == null) return "NORMAL";
        if (spo2 < 90) return "CRITICAL";
        if (spo2 < 95) return "HIGH";
        return "NORMAL";
    }
    
    private String determineBPAlert(Integer systolic, Integer diastolic) {
        if (systolic != null && systolic > 180) return "CRITICAL";
        if (diastolic != null && diastolic > 110) return "CRITICAL";
        if (systolic != null && systolic > 140) return "HIGH";
        if (diastolic != null && diastolic > 90) return "HIGH";
        if (systolic != null && systolic < 90) return "LOW";
        if (diastolic != null && diastolic < 60) return "LOW";
        return "NORMAL";
    }
    
    /**
     * Helper method to send vital alerts only if Firebase is enabled
     */
    private void sendVitalAlertIfEnabled(Long patientId, String type, String value, String alertLevel) {
        if (notificationService != null) {
            notificationService.sendVitalAlert(patientId, type, value, alertLevel);
        }
    }
}
