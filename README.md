# NXT Hospital – IVR Appointment

This module is an extension of the NXT Hospital Management System (HMS) designed to streamline the process of doctor appointments through an Interactive Voice Response (IVR) system. It allows patients to book appointments by interacting via a phone call and get routed based on department and doctor availability.

---

## 📌 Key Features

- IVR-driven appointment scheduling.
- Department-wise segregation of doctors.
- Real-time doctor availability based on schedules.
- Schedule management by doctors or their receptionists.
- Seamless integration into existing NXT Hospital HMS.
- Notification support (SMS/Email) for appointment confirmation.

---

## ⚙️ System Architecture

1. **Caller → IVR System**
2. **IVR → Department Selection**
3. **Department → Doctor's Schedule Lookup**
4. **Schedule Available → Book Slot**
5. **Confirmation Sent → Patient**

---

## 🏗️ Module Components

- `doctor-schedule`: Backend API for managing doctor availability.
- `appointment-service`: Handles booking, validation, and IVR routing.
- `ivr-engine`: IVR flow logic (built with [your IVR framework/tool]).
- `reception-interface`: UI for receptionists to manage appointments.
- `notifications`: Sends appointment confirmations via SMS/Email.

## 📞 Contact

For Integration support or custom deployment contact: 

### Work Email: `nxtwebmasters@gmail.com`
### Personal Email: `shahmobeen333@gmail.com`
### Phone: `+92 312 8776604`