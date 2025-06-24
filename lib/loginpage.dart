import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ScanPage.dart';
import 'SupervisorDashboard.dart';
import 'area_manager_dashboard.dart';
import 'EhsManagerDashboard.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF009688),
        body: Column(
          children: [
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC0FF33), width: 2),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: const Color(0xFFC0FF33),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: const [
                    Tab(text: 'Log In'),
                    Tab(text: 'Sign Up'),
                  ],
                  indicatorSize: TabBarIndicatorSize.tab,
                ),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  LoginPage(),
                  SignupPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  bool obscure = true;

  bool mobileError = false;
  bool passwordError = false;

  void validateAndLogin() {
    setState(() {
      mobileError = mobileController.text.trim().isEmpty;
      passwordError = passwordController.text.trim().isEmpty;
    });

    if (!mobileError && !passwordError) {
      // Do login action here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful!")),
      );
    }
  }

  InputDecoration inputDecoration({
    required String hint,
    required bool error,
  }) =>
      InputDecoration(
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: error ? Colors.red : const Color(0xFF009688), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: error ? Colors.red : const Color(0xFF009688), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: error ? Colors.red : const Color(0xFFC0FF33), width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget fieldTitle(String title) {
    return RichText(
      text: TextSpan(
        text: title,
        style: const TextStyle(
            color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  Future<void> submitLogin() async {
    if (mobileController.text.trim().isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields!")),
      );
      return;
    }

    const String apiUrl = "https://esheapp.in/GE/App/login.php"; // your URL

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": mobileController.text.trim(),
          "password": passwordController.text,
        }),
      );

      print('Login API response: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final user = data['user'];
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', user['phone'] ?? user['phone_number'] ?? '');
        await prefs.setString('full_name', user['fullname'] ?? user['full_name'] ?? '');
        await prefs.setString('category', user['category'] ?? '');
        await prefs.setString('approval_type', user['approval_type'] ?? '');
        await prefs.setString('email', user['email'] ?? '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome, ${user['fullname'] ?? user['full_name'] ?? ''}! Login successful.")),
        );
        // Clear input fields:
        mobileController.clear();
        passwordController.clear();

        // === Category-based navigation ===
        final String category = (user['category'] ?? '').toString().toLowerCase();

        if (category == 'operator') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const OperatorDashboard()));
        } else if (category == 'supervisor') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const SupervisorDashboard()));
        } else if (category == 'area manager') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const AreaManagerDashboard()));
        }else if (category == 'ehs manager') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const EhsmanagerDashboard()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const SupervisorDashboard()));
        }
        // ================================

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Login failed.")),
        );
      }
    } catch (e) {
      print('Login Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Card(
          elevation: 6,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.white,
                    child: Image.asset(
                      "assets/ge_logo.png", // Replace with your logo or use FlutterLogo
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) =>
                          FlutterLogo(size: 80),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        DefaultTabController.of(context).animateTo(1);
                      },
                      child: const Text("Sign Up",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldTitle("Mobile number"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: inputDecoration(
                        hint: 'Enter mobile number',
                        error: mobileError,
                      ),
                    ),
                    if (mobileError)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 3),
                        child: Text(
                          "Mobile number is required",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    fieldTitle("Password"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: inputDecoration(
                        hint: 'Enter password',
                        error: passwordError,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => obscure = !obscure);
                          },
                        ),
                      ),
                    ),
                    if (passwordError)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 3),
                        child: Text(
                          "Password is required",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() => rememberMe = value!);
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      activeColor: const Color(0xFF009688),
                    ),
                    const Text('Remember me'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                            color: Color(0xFF009688),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Login Button with gradient, border, and shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC0FF33), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.13),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: submitLogin,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF009688), Color(0xFF43E97B)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscure = true;
  // Error flags
  bool nameError = false;
  bool emailError = false;
  bool companyError = false;
  bool designationError = false;
  bool phoneError = false;
  bool passwordError = false;

  void validateAndRegister() {
    setState(() {
      nameError = nameController.text.trim().isEmpty;
      emailError = emailController.text.trim().isEmpty;
      companyError = companyController.text.trim().isEmpty;
      designationError = designationController.text.trim().isEmpty;
      phoneError = phoneController.text.trim().isEmpty;
      passwordError = passwordController.text.trim().isEmpty;
    });

    // If all fields are filled
    if (!nameError && !emailError && !companyError && !designationError && !phoneError && !passwordError) {
      // Proceed with registration logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered Successfully!")),
      );
    }
  }
  Future<void> submitSignup() async {
    // Basic validation for empty fields
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        companyController.text.trim().isEmpty ||
        designationController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    // Optional: Email format validation
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address!")),
      );
      return;
    }

    // Optional: Phone number format check (simple)
    if (phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number!")),
      );
      return;
    }

    // API endpoint
    const String apiUrl = "https://esheapp.in/GE/App/signup.php"; // Fixed typo

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fullname": nameController.text.trim(),
          "email": emailController.text.trim(),
          "company": companyController.text.trim(),
          "designation": designationController.text.trim(),
          "phone": phoneController.text.trim(),
          "password": passwordController.text,
        }),
      );

      // 👇 PRINT the raw response for debugging
      print('Signup API response: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Signup successful!")),
        );
        // Optionally clear all fields:
        nameController.clear();
        emailController.clear();
        companyController.clear();
        designationController.clear();
        phoneController.clear();
        passwordController.clear();
        // Optionally navigate to login tab:
        DefaultTabController.of(context)?.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Signup failed.")),
        );
      }
    } catch (e) {
      print('Signup Exception: $e'); // 👈 Print exception in debug console
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  Widget fieldTitle(String title) {
    return RichText(
      text: TextSpan(
        text: title,
        style: const TextStyle(
            color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  InputDecoration inputDecoration({String? hint}) => InputDecoration(
    hintText: hint ?? '',
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF009688), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF009688), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC0FF33), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        DefaultTabController.of(context)?.animateTo(0); // Switch to Login tab
                      },
                      child: const Text(
                        "Log In",
                        style: TextStyle(
                          color: Color(0xFFC0FF33),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name
                        fieldTitle("Full Name"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: inputDecoration(hint: "Full Name"),
                        ),
                        if (nameError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Full Name is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Email
                        fieldTitle("Email"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: inputDecoration(hint: "Email"),
                        ),
                        if (emailError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Email is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Company Name
                        fieldTitle("Company name"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: companyController,
                          decoration: inputDecoration(hint: "Company name"),
                        ),
                        if (companyError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Company name is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Designation
                        fieldTitle("Designation"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: designationController,
                          decoration: inputDecoration(hint: "Designation"),
                        ),
                        if (designationError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Designation is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Phone Number (with country prefix)
                        fieldTitle("Phone Number"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: inputDecoration(hint: "Phone Number").copyWith(
                            prefixIcon: Container(
                              padding: const EdgeInsets.only(left: 8, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.network(
                                    'https://flagcdn.com/in.svg',
                                    width: 26,
                                    height: 22,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text("+91", style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (phoneError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Phone Number is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Set Password
                        fieldTitle("Set Password"),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: obscure,
                          decoration: inputDecoration(hint: "Set Password").copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() => obscure = !obscure);
                              },
                            ),
                          ),
                        ),
                        if (passwordError)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 3),
                            child: Text(
                              "Password is required",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: submitSignup,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.black26,
                              elevation: 1,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF009688), Color(0xFF43E97B)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFFC0FF33),
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

