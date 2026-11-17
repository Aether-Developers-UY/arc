<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'username' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);
        $credentials['username'] = User::normalizeUsername($credentials['username']);

        if (! Auth::attempt($credentials)) {
            throw ValidationException::withMessages([
                'username' => ['Usuario o contraseña incorrectos.'],
            ]);
        }

        /** @var User $user */
        $user = User::where('username', $credentials['username'])->firstOrFail();
        $token = $user->createToken('arc-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->toProfileArray(),
        ]);
    }

    public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user()->toProfileArray(),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Sesión cerrada.']);
    }
}
