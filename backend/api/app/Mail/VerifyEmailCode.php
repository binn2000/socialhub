<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class VerifyEmailCode extends Mailable implements ShouldQueue
{
    use Queueable, SerializesModels;

    public function __construct(public string $name, public string $code)
    {
    }

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Mã xác thực email SocialHub');
    }

    public function content(): Content
    {
        return new Content(text: 'mail.verify-email');
    }
}
