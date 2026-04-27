package dev.ogos.anotheriptvplayer

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.RepeatMode

@Composable
fun TvWelcomeScreen(onDone: () -> Unit) {
    val vm: TvWelcomeViewModel = viewModel()
    val step by vm.currentStep.collectAsState()
    val errorMessage by vm.errorMessage.collectAsState()
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A0F))
    ) {
        when (step) {
            is WelcomeStep.Welcome -> WelcomeStepScreen(vm)
            is WelcomeStep.LoginForm -> LoginFormScreen(vm, context)
            is WelcomeStep.RegisterForm -> RegisterFormScreen(vm, context)
            is WelcomeStep.Syncing -> SyncingScreen()
            is WelcomeStep.Error -> ErrorScreen(vm, errorMessage)
            is WelcomeStep.Done -> {
                LaunchedEffect(Unit) {
                    onDone()
                }
            }
        }
    }
}

@Composable
fun WelcomeStepScreen(vm: TvWelcomeViewModel) {
    val loginFocus = remember { FocusRequester() }
    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        visible = true
        loginFocus.requestFocus()
    }

    Row(modifier = Modifier.fillMaxSize()) {
        // Left Half
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(64.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = "C4-TV",
                style = MaterialTheme.typography.displayLarge,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Your entertainment. Anywhere.",
                style = MaterialTheme.typography.headlineSmall,
                color = Color(0xFF9A9AA8)
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "Version 1.0",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF9A9AA8)
            )
        }

        // Right Half
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(64.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            AnimatedVisibility(
                visible = visible,
                enter = fadeIn(animationSpec = tween(500)) + slideInVertically(animationSpec = tween(500), initialOffsetY = { 50 })
            ) {
                Button(
                    onClick = { vm.setStep(WelcomeStep.LoginForm) },
                    modifier = Modifier
                        .width(300.dp)
                        .height(56.dp)
                        .focusRequester(loginFocus),
                    colors = ButtonDefaults.colors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        focusedContainerColor = Color.White,
                        contentColor = Color.White,
                        focusedContentColor = MaterialTheme.colorScheme.primary
                    )
                ) {
                    Text("Login")
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            AnimatedVisibility(
                visible = visible,
                enter = fadeIn(animationSpec = tween(500, delayMillis = 100)) + slideInVertically(animationSpec = tween(500, delayMillis = 100), initialOffsetY = { 50 })
            ) {
                OutlinedButton(
                    onClick = { vm.setStep(WelcomeStep.RegisterForm) },
                    modifier = Modifier
                        .width(300.dp)
                        .height(56.dp),
                    colors = ButtonDefaults.colors(
                        containerColor = Color.Transparent,
                        focusedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                        contentColor = MaterialTheme.colorScheme.primary,
                        focusedContentColor = Color.White
                    ),
                    border = OutlinedButtonDefaults.border(
                        border = androidx.tv.material3.Border(androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.primary)),
                        focusedBorder = androidx.tv.material3.Border(androidx.compose.foundation.BorderStroke(2.dp, Color.White))
                    )
                ) {
                    Text("Register")
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            AnimatedVisibility(
                visible = visible,
                enter = fadeIn(animationSpec = tween(500, delayMillis = 200)) + slideInVertically(animationSpec = tween(500, delayMillis = 200), initialOffsetY = { 50 })
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Surface(
                        onClick = {
                            vm.isGuestMode = true
                            vm.setStep(WelcomeStep.Done)
                        },
                        modifier = Modifier
                            .width(300.dp)
                            .height(56.dp),
                        colors = ClickableSurfaceDefaults.colors(
                            containerColor = Color.Transparent,
                            focusedContainerColor = MaterialTheme.colorScheme.surface
                        )
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("Continue as Guest", color = Color(0xFF9A9AA8))
                        }
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("Add a playlist manually", style = MaterialTheme.typography.bodySmall, color = Color(0xFF9A9AA8).copy(alpha = 0.7f))
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun LoginFormScreen(vm: TvWelcomeViewModel, context: android.content.Context) {
    var serverUrl by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier = Modifier
            .fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(modifier = Modifier.width(360.dp)) {
            Text("Sign In", style = MaterialTheme.typography.headlineMedium, color = Color.White)
            Spacer(modifier = Modifier.height(8.dp))
            Text("Use your sync account to restore everything", style = MaterialTheme.typography.bodyMedium, color = Color(0xFF9A9AA8))
            Spacer(modifier = Modifier.height(24.dp))

            androidx.compose.material3.OutlinedTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp)
                    .focusRequester(focusRequester),
                placeholder = { androidx.compose.material3.Text("https://sync.example.com", color = Color.Gray) },
                label = { androidx.compose.material3.Text("Server URL", color = Color.Gray) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Email", color = Color.Gray) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Password", color = Color.Gray) },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(32.dp))

            Button(
                onClick = { vm.signIn(context, serverUrl, email, password) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.colors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    focusedContainerColor = Color.White,
                    contentColor = Color.White,
                    focusedContentColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Text("Sign In")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Surface(
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ClickableSurfaceDefaults.colors(
                    containerColor = Color.Transparent,
                    focusedContainerColor = MaterialTheme.colorScheme.surface
                )
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("← Back", color = Color(0xFF9A9AA8))
                }
            }

            val error = vm.errorMessage.collectAsState().value
            if (error != null) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(error, color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun RegisterFormScreen(vm: TvWelcomeViewModel, context: android.content.Context) {
    var serverUrl by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier = Modifier
            .fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Column(modifier = Modifier.width(360.dp)) {
            Text("Create Account", style = MaterialTheme.typography.headlineMedium, color = Color.White)
            Spacer(modifier = Modifier.height(24.dp))

            androidx.compose.material3.OutlinedTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp)
                    .focusRequester(focusRequester),
                placeholder = { androidx.compose.material3.Text("https://sync.example.com", color = Color.Gray) },
                label = { androidx.compose.material3.Text("Server URL", color = Color.Gray) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Full Name", color = Color.Gray) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Email", color = Color.Gray) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = password,
                onValueChange = { password = it; localError = null },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Password", color = Color.Gray) },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Next),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            Spacer(modifier = Modifier.height(16.dp))
            androidx.compose.material3.OutlinedTextField(
                value = confirmPassword,
                onValueChange = { confirmPassword = it; localError = null },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp),
                label = { androidx.compose.material3.Text("Confirm Password", color = Color.Gray) },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = Color.Gray,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                )
            )
            
            val error = localError ?: vm.errorMessage.collectAsState().value
            if (error != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(error, color = MaterialTheme.colorScheme.error)
            }

            Spacer(modifier = Modifier.height(32.dp))

            Button(
                onClick = { 
                    if (password != confirmPassword) {
                        localError = "Passwords do not match"
                    } else {
                        vm.register(context, serverUrl, name, email, password)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.colors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    focusedContainerColor = Color.White,
                    contentColor = Color.White,
                    focusedContentColor = MaterialTheme.colorScheme.primary
                )
            ) {
                Text("Create Account")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Surface(
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ClickableSurfaceDefaults.colors(
                    containerColor = Color.Transparent,
                    focusedContainerColor = MaterialTheme.colorScheme.surface
                )
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("← Back", color = Color(0xFF9A9AA8))
                }
            }
        }
    }
}

@Composable
fun SyncingScreen() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        val infiniteTransition = rememberInfiniteTransition()
        val alpha by infiniteTransition.animateFloat(
            initialValue = 0.6f,
            targetValue = 1.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(1000),
                repeatMode = RepeatMode.Reverse
            ), label = "alpha"
        )
        androidx.compose.material3.CircularProgressIndicator(
            modifier = Modifier.size(64.dp),
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = "Connecting to your account…",
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White.copy(alpha = alpha)
        )
    }
}

@Composable
fun ErrorScreen(vm: TvWelcomeViewModel, errorMessage: String?) {
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            Icons.Default.ErrorOutline,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.error
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = errorMessage ?: "An unknown error occurred",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White,
            maxLines = 2,
            modifier = Modifier.widthIn(max = 400.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        Spacer(modifier = Modifier.height(32.dp))
        Button(
            onClick = { vm.setStep(WelcomeStep.Welcome) },
            modifier = Modifier
                .width(300.dp)
                .height(56.dp)
                .focusRequester(focusRequester),
            colors = ButtonDefaults.colors(
                containerColor = MaterialTheme.colorScheme.primary,
                focusedContainerColor = Color.White,
                contentColor = Color.White,
                focusedContentColor = MaterialTheme.colorScheme.primary
            )
        ) {
            Text("Try Again")
        }
        Spacer(modifier = Modifier.height(16.dp))
        OutlinedButton(
            onClick = { 
                vm.isGuestMode = true
                vm.setStep(WelcomeStep.Done) 
            },
            modifier = Modifier
                .width(300.dp)
                .height(56.dp),
            colors = ButtonDefaults.colors(
                containerColor = Color.Transparent,
                focusedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                contentColor = MaterialTheme.colorScheme.primary,
                focusedContentColor = Color.White
            ),
            border = OutlinedButtonDefaults.border(
                border = androidx.tv.material3.Border(androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.primary)),
                focusedBorder = androidx.tv.material3.Border(androidx.compose.foundation.BorderStroke(2.dp, Color.White))
            )
        ) {
            Text("Continue as Guest")
        }
    }
}
