package wildproto;
$VERSION = 1.0;

use base pragmatic;

bootstrap xsub;

use xsub q{
  static bool active = FALSE;

  OP *(*old_ck_entersub)(pTHX_ OP *);

  static OP *new_ck_entersub(pTHX_ OP *o) {
    OP *op;
    char *real_proto = NULL;
    char *copy_proto = NULL;

    if (active) {
      UNOP *uno = (UNOP *)o;
      OP *prev;
      OP *argop;
      OP *cvop;
      char *proto = 0;
      CV *cv = 0;
      SVOP *tmpop;

      if (o->op_private & OPpENTERSUB_AMPER)
        goto real_op;

      prev = uno->op_first->op_sibling ? o : uno->op_first;
      prev = ((UNOP *)prev)->op_first;
      argop = prev->op_sibling;

      for (cvop = argop; cvop->op_sibling; cvop = cvop->op_sibling);
    
      if (cvop->op_type != OP_RV2CV)
        goto real_op;
      if (cvop->op_private & OPpENTERSUB_AMPER)
        goto real_op;
      tmpop = (SVOP*)((UNOP*)cvop)->op_first;
      if (tmpop->op_type != OP_GV)
        goto real_op;
    
      cv = GvCVu(cGVOPx_gv(tmpop));
      if (!cv || !SvPOK(cv))
        goto real_op;
      proto = SvPV_nolen((SV*)cv);
    
      while (argop != cvop) {
#ifdef WACKYPROTO
        int type = 0;
#endif

        while (*proto == ' ' || *proto == ';')
          proto++;
        if (!*proto || *proto == '@' || *proto == '%')
          break;

        if (*proto == '\\\\' && *(proto+1) == '?')
#ifdef WACKYPROTO
          type = 1;
        else if (*(proto+0) == '(' && *(proto+1) == ')') 
          type = 2;
        else if (*(proto+0) == '[' && *(proto+1) == ']') type = 3;
        else if (*(proto+0) == '{' && *(proto+1) == '}') type = 4;
        else type = 0;

        if (type)
#endif
        {
          OP *next = argop->op_sibling;
          argop->op_sibling = 0;

#ifdef WACKYPROTO
          switch (type) {
          case 1:
#endif
            argop = newUNOP(OP_REFGEN, 0, mod(argop, OP_REFGEN));
#ifdef WACKYPROTO
            break;
          case 2:
            argop = newUNOP(OP_REFGEN, 0, mod(argop, OP_REFGEN));
            argop = newANONLIST(argop);
            break;
          case 3:
            argop = newANONLIST(argop);
            break;
          case 4:
            argop = newANONHASH(argop);
            break;
          }
#endif

          argop->op_sibling = next;
          prev->op_sibling = argop;
          if (!real_proto) {
            real_proto = proto;
            copy_proto = savepv(proto);
          }
          *proto++ = ' ';
          *proto = '$';
        }

        if (*proto == '\\\\')
          if (!*++proto)
            break;
    
        proto++;
        prev = argop;
        argop = argop->op_sibling;
      }
    }

  real_op:
    op = old_ck_entersub(aTHX_ o);
    if (real_proto)
      strcpy(real_proto, copy_proto);
    return op;
  }
};

use xsub enable => q($), q{
  if (active)
    return &PL_sv_yes;

  old_ck_entersub = PL_check[OP_ENTERSUB];
  PL_check[OP_ENTERSUB] = new_ck_entersub;

  active = TRUE;
  return &PL_sv_yes;
};

use xsub disable => q($), q{
  if (!active)
    return &PL_sv_yes;

  active = FALSE;
  if (PL_check[OP_ENTERSUB] == new_ck_entersub) {
    PL_check[OP_ENTERSUB] = old_ck_entersub;
  } else {
    Perl_warn(aTHX_ "PL_check[OP_ENTERSUB] apparently hijacked at %s line %d\n",
      __FILE__, __LINE__);
  }

  return &PL_sv_no;
};

1
