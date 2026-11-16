<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAttachmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'in:audio,pdf,other'],
            'file' => [
                'required',
                'file',
                'max:20480', // 20MB in kilobytes
                // mp4 also covers .m4a files, which are often detected as
                // video/mp4; keep it even if only audio is expected.
                'mimes:mp3,mp4,m4a,wav,pdf',
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'file.max' => 'El archivo supera el tamaño máximo permitido.',
            'file.mimes' => 'Solo se admiten archivos MP3, WAV, M4A, MP4 o PDF.',
        ];
    }
}
