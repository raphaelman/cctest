package com.careconnect.security;

import com.careconnect.model.User;
import com.careconnect.repository.UserRepository;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class UserDetailsServiceImpl implements org.springframework.security.core.userdetails.UserDetailsService {

    private final UserRepository users;

    public UserDetailsServiceImpl(UserRepository users) {
        this.users = users;
    }

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        User user = users.findByEmail(email).orElseThrow(() -> new UsernameNotFoundException("User not found"));
        return new org.springframework.security.core.userdetails.User(user.getEmail(), user.getPassword(),
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name())));
    }

    public ResponseEntity<?> extractUserProfile(Object principal) {
        if (principal instanceof OAuth2User oAuth2User) {
            return ResponseEntity.ok(Map.of(
                "email", oAuth2User.getAttribute("email"),
                "name", oAuth2User.getAttribute("name"),
                "role", oAuth2User.getAuthorities().stream()
                        .findFirst().map(Object::toString).orElse("UNKNOWN")
            ));
        } else if (principal instanceof UserDetails user) {
            return ResponseEntity.ok(Map.of(
                "email", user.getUsername(),
                "role", user.getAuthorities().stream()
                        .findFirst().map(Object::toString).orElse("UNKNOWN")
            ));
        } else {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("No authenticated user");
        }
    }
}
